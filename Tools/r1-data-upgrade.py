#!/usr/bin/env python3
"""Offline NanaFlow preference plan/backup; defaults to prepare only.

No app launch, defaults command, CFPreferences/KVS access, daemon manipulation,
or arbitrary source/target paths. Keep the app closed throughout the operation.
Production prepare/verify do not restore preferences. Production apply/rollback
are disabled until protected-container access and preference-cache integration
are validated; only explicit synthetic fixtures can exercise those actions.
"""
import argparse
import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import uuid

BUNDLE = 'com.nanafox.NanaFlow'
FIXTURE_BUNDLE = BUNDLE + '.R1DataUpgradeFixture'
MARKER = b'NANAFLOW_SYNTHETIC_FIXTURE_V1\n'
HISTORY, TAGS = 'focusSessions.v1', 'sessionTags.v1'
MAX_BYTES = 32 * 1024 * 1024
UNSET = object()
INT64_MIN, INT64_MAX, UINT64_MAX = -(2 ** 63), 2 ** 63 - 1, 2 ** 64 - 1
PREFERENCE_REQUIRED_BOOLS = ['autoStartFocus', 'autoStartBreaks', 'notificationSoundEnabled']
PREFERENCE_DEFAULTED_BOOLS = [
    'commitmentModeEnabled', 'showWindowOnLaunch', 'resetCycleOnLaunch', 'startTimerOnLaunch',
    'hideWindowWhenTimerStarts', 'fullscreenBreaks', 'tickingSoundEnabled', 'calendarSyncEnabled',
    'timerSyncEnabled', 'notificationsEnabled', 'motivationalQuotesEnabled', 'showTodayCompletedCount',
    'showMenuBarTitle', 'coloredMenuBarIconDuringBreak', 'globalHotkeysEnabled']
PREFERENCE_KNOWN_KEYS = PREFERENCE_REQUIRED_BOOLS + PREFERENCE_DEFAULTED_BOOLS + [
    'tickingVolume', 'notificationVolume', 'sessionTitle', 'calendarIdentifier', 'appearance',
    'menuBarIconStyle', 'focusCompletionSound', 'breakCompletionSound', 'globalShortcuts']
# GlobalShortcutSet.flowDefault, after normalized NSEvent command/option/control
# flags (0x1c0000). Materialize only to retain unknown nested shortcut fields
# when the authoritative value decodes to its default set.
DEFAULT_SHORTCUTS = {name: {'keyCode': code, 'modifiersRawValue': 0x1c0000}
                     for name, code in [('toggle', 3), ('skip', 1), ('reset', 15), ('showOrHideWindow', 4)]}

class UpgradeError(Exception):
    pass

def require(value, code='invalid_payload'):
    if not value:
        raise UpgradeError(code)

class UniqueDict(dict):
    def __setitem__(self, key, value):
        require(key not in self, 'duplicate_dictionary_field')
        super().__setitem__(key, value)

def pairs(items):
    value = UniqueDict()
    for key, item in items:
        value[key] = item
    return value

def plain(value):
    if isinstance(value, dict):
        return {key: plain(item) for key, item in value.items()}
    if isinstance(value, list):
        return [plain(item) for item in value]
    return value

def digest(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None

def no_links(path):
    for part in [path, *path.parents]:
        require(not part.is_symlink(), 'unsafe_path')

def read_file(path):
    no_links(path)
    if not path.exists():
        return None
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_uid == os.getuid()
                and before.st_nlink == 1 and before.st_size <= MAX_BYTES, 'unsafe_file')
        data = b''
        while True:
            block = os.read(fd, 65536)
            if not block:
                break
            data += block
            require(len(data) <= MAX_BYTES, 'payload_too_large')
        after = os.fstat(fd)
        require((before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), 'file_changed_during_read')
        return data
    finally:
        os.close(fd)

def number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False

def swift_integer(value, unsigned=False):
    # NanaFlow's supported 64-bit Swift Int/UInt; Bool is not an integer payload.
    return type(value) is int and (0 if unsigned else INT64_MIN) <= value <= (UINT64_MAX if unsigned else INT64_MAX)

def defaulted(value, key, fallback):
    # Codable decodeIfPresent treats only missing/null as the fallback, not false/0.
    item = value.get(key)
    return fallback if item is None else item

def guard_runtime_restore(action, synthetic):
    require(synthetic or action not in ['apply', 'rollback'], 'runtime_restore_not_validated')

def decode_json(data, expected):
    require(isinstance(data, bytes))
    try:
        value = json.loads(data, object_pairs_hook=pairs,
                           parse_constant=lambda _: (_ for _ in ()).throw(UpgradeError('invalid_payload')))
    except (ValueError, UnicodeError, TypeError):
        raise UpgradeError('invalid_payload')
    require(isinstance(value, expected))
    return plain(value)

def encode_json(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()

def history(data):
    rows = decode_json(data, list)
    found = {}
    for row in rows:
        require(isinstance(row, dict))
        try:
            identity = str(uuid.UUID(row.get('id', '')))
        except (ValueError, AttributeError, TypeError):
            raise UpgradeError('invalid_payload')
        require(all(number(row.get(k)) for k in ['startedAt', 'endedAt', 'duration']))
        require(row['endedAt'] >= row['startedAt'] and row['duration'] >= 0)
        require(type(row.get('completed')) is bool and isinstance(row.get('title'), str))
        require(defaulted(row, 'type', 'focus') in ['focus', 'shortBreak', 'longBreak'])
        require(row.get('tag') is None or isinstance(row['tag'], str))
        interruptions = defaulted(row, 'interruptions', [])
        require(isinstance(interruptions, list))
        for item in interruptions:
            require(isinstance(item, dict) and number(item.get('stoppedAt')))
            require(item.get('resumedAt') is None or number(item['resumedAt']))
        # Identical duplicates collapse; conflicting duplicates within one store
        # are ambiguous and require review rather than silently discarding data.
        require(identity not in found or found[identity] == row, 'conflicting_duplicate_uuid')
        found[identity] = row
    return found

def tags(data):
    value = decode_json(data, dict)
    require(isinstance(value.get('tags'), list) and all(isinstance(x, str) and x for x in value['tags']))
    require(value.get('selectedTag') is None or isinstance(value['selectedTag'], str))
    colors = defaulted(value, 'colors', {})
    require(isinstance(colors, dict))
    require(all(isinstance(k, str) and isinstance(v, str) for k, v in colors.items()))
    if value.get('colors') is None:
        value['colors'] = colors
    return plain(value)

def preferences(data):
    value = decode_json(data, dict)
    require(all(type(value.get(k)) is bool for k in PREFERENCE_REQUIRED_BOOLS))
    for key in PREFERENCE_DEFAULTED_BOOLS:
        require(value.get(key) is None or type(value[key]) is bool)
    for key in ['tickingVolume', 'notificationVolume']:
        require(value.get(key) is None or number(value[key]))
    for key in ['sessionTitle', 'calendarIdentifier']:
        require(key not in value or value[key] is None or isinstance(value[key], str))
    choices = {'appearance': ['system', 'light', 'dark'], 'menuBarIconStyle': ['default', 'circle', 'list', 'progress']}
    sounds = ['none', 'alarmClock', 'bell', 'bells', 'bowl', 'chime', 'chord', 'harp', 'milestone', 'pulse', 'ripple', 'whistle']
    choices.update(focusCompletionSound=sounds, breakCompletionSound=sounds)
    for key, allowed in choices.items():
        require(value.get(key) is None or value[key] in allowed)
    if value.get('globalShortcuts') is not None:
        shortcuts = value['globalShortcuts']
        require(isinstance(shortcuts, dict))
        for key in ['toggle', 'skip', 'reset', 'showOrHideWindow']:
            entry = shortcuts.get(key)
            require(isinstance(entry, dict) and type(entry.get('keyCode')) is int and 0 <= entry['keyCode'] <= 65535
                    and swift_integer(entry.get('modifiersRawValue'), unsigned=True))

def engine(data):
    value = decode_json(data, dict)
    config, state = value.get('configuration'), value.get('state')
    require(isinstance(config, dict) and isinstance(state, dict))
    require(all(number(config.get(k)) and config[k] > 0 for k in ['focusDuration', 'shortBreakDuration', 'longBreakDuration']))
    require(swift_integer(config.get('sessionsPerCycle')) and config['sessionsPerCycle'] >= 1)
    require(state.get('phase') in ['focus', 'shortBreak', 'longBreak'])
    require(swift_integer(state.get('cycleIndex')) and state['cycleIndex'] >= 0 and number(state.get('remainingWhenPaused')))
    for key in ['endDate', 'startedAt']:
        require(state.get(key) is None or number(state[key]))
    interruptions = defaulted(state, 'interruptions', [])
    require(isinstance(interruptions, list))
    for item in interruptions:
        require(isinstance(item, dict) and number(item.get('stoppedAt')))
        require(item.get('resumedAt') is None or number(item['resumedAt']))

def decode_plist(data):
    if data is None:
        return {}
    try:
        value = plistlib.loads(data, dict_type=UniqueDict)
    except (ValueError, TypeError, plistlib.InvalidFileException, OverflowError):
        raise UpgradeError('invalid_payload')
    require(isinstance(value, dict) and all(isinstance(k, str) for k in value))
    for key, validator in [('timerEngine.v1', engine), ('timerPreferences.v1', preferences),
                           (HISTORY, history), (TAGS, tags)]:
        if key in value:
            validator(value[key])
    for key in ['welcome.hasBeenShown', 'welcome.showAtLaunch']:
        require(key not in value or type(value[key]) is bool)
    for key in ['NanaFlow.deviceKey.v1', 'NanaFlow.syncKey.v1']:
        require(key not in value or isinstance(value[key], str))
    return plain(value)

def overlay(authoritative, other):
    result = copy.deepcopy(other)
    for key, value in authoritative.items():
        result[key] = overlay(value, result[key]) if isinstance(value, dict) and isinstance(result.get(key), dict) else copy.deepcopy(value)
    return result

def known_overlay(authoritative, other, known_keys):
    result = overlay(authoritative, other)
    # Missing known fields have Codable nil/default semantics. Only unknown
    # fields may be inherited from the other snapshot when absent here.
    for key in known_keys:
        if key not in authoritative:
            result.pop(key, None)
    return result

def session_overlay(authoritative, other):
    return known_overlay(authoritative, other, ['tag', 'type', 'interruptions'])

def merge(legacy, target):
    result = overlay(legacy, target)
    key = 'timerEngine.v1'
    if key in legacy and key in target:
        current, other = decode_json(legacy[key], dict), decode_json(target[key], dict)
        combined = overlay(current, other)
        combined['state'] = known_overlay(current['state'], other['state'], ['endDate', 'startedAt', 'interruptions'])
        result[key] = encode_json(combined)
    key = 'timerPreferences.v1'
    if key in legacy and key in target:
        current, other = decode_json(legacy[key], dict), decode_json(target[key], dict)
        combined = known_overlay(current, other, PREFERENCE_KNOWN_KEYS)
        if current.get('globalShortcuts') is None and isinstance(other.get('globalShortcuts'), dict):
            combined['globalShortcuts'] = overlay(DEFAULT_SHORTCUTS, other['globalShortcuts'])
        result[key] = encode_json(combined)
    if HISTORY in legacy or HISTORY in target:
        rows = history(target[HISTORY]) if HISTORY in target else {}
        for identity, row in (history(legacy[HISTORY]) if HISTORY in legacy else {}).items():
            rows[identity] = session_overlay(row, rows.get(identity, {}))
        result[HISTORY] = encode_json(sorted(rows.values(), key=lambda r: (-r['endedAt'], str(r['id']))))
    if TAGS in legacy or TAGS in target:
        old = tags(legacy[TAGS]) if TAGS in legacy else {}
        other = tags(target[TAGS]) if TAGS in target else {}
        combined = known_overlay(old, other, ['selectedTag']) if TAGS in legacy else overlay(old, other)
        combined['tags'] = list(dict.fromkeys(old.get('tags', []) + other.get('tags', [])))
        combined['colors'] = {**other.get('colors', {}), **old.get('colors', {})}
        result[TAGS] = encode_json(combined)
    decode_plist(plistlib.dumps(result))
    return result

def rollback_merge(baseline, current, candidate):
    result = merge(baseline, current)
    if HISTORY in current:
        previous = history(candidate[HISTORY]) if HISTORY in candidate else {}
        rows = history(result[HISTORY])
        for identity, row in history(current[HISTORY]).items():
            if previous.get(identity) != row:
                rows[identity] = session_overlay(row, rows.get(identity, {}))
        result[HISTORY] = encode_json(sorted(rows.values(), key=lambda r: (-r['endedAt'], str(r['id']))))
    if TAGS in current:
        now = tags(current[TAGS])
        old = tags(candidate[TAGS]) if TAGS in candidate else {}
        merged = tags(result[TAGS])
        for name, color in now.get('colors', {}).items():
            if old.get('colors', {}).get(name) != color:
                merged['colors'][name] = color
        if now.get('selectedTag') != old.get('selectedTag'):
            merged['selectedTag'] = now.get('selectedTag')
        result[TAGS] = encode_json(merged)
    return result

def fsync_dir(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)

def mkdir_durable(path):
    no_links(path)
    missing = []
    current = path
    while not current.exists():
        missing.append(current)
        current = current.parent
    for directory in reversed(missing):
        directory.mkdir(mode=0o700)
        fsync_dir(directory.parent)

class Upgrader:
    def __init__(self, args):
        guard_runtime_restore(args.action, args.synthetic_root is not None)
        self.args = args
        self.synthetic = args.synthetic_root is not None
        self.bundle = args.bundle_id or (FIXTURE_BUNDLE if self.synthetic else BUNDLE)
        require(self.bundle == (FIXTURE_BUNDLE if self.synthetic else BUNDLE), 'wrong_bundle_identity')
        if self.synthetic:
            self.home = Path(args.synthetic_root)
            require(self.home.is_absolute() and self.home.exists() and self.home == self.home.resolve(), 'unsafe_fixture_root')
            no_links(self.home)
            info = self.home.stat()
            require(info.st_uid == os.getuid() and stat.S_ISDIR(info.st_mode) and info.st_mode & 0o077 == 0, 'unsafe_fixture_root')
            real_library = (Path.home() / 'Library').resolve()
            require(self.home != Path.home().resolve() and real_library not in [self.home, *self.home.parents], 'unsafe_fixture_root')
            require(read_file(self.home / '.nanaflow-synthetic-fixture') == MARKER, 'fixture_marker_required')
        else:
            self.home = Path.home()
        require(not args.fault or self.synthetic, 'synthetic_fault_only')
        self.legacy = self.home / 'Library/Preferences' / (self.bundle + '.plist')
        self.target = self.home / 'Library/Containers' / self.bundle / 'Data/Library/Preferences' / (self.bundle + '.plist')
        self.state = (self.home / 'transactions' if self.synthetic else
                      self.home / 'Library/Application Support/NanaFlow/DataUpgrade')
        self.guard_stopped()
        no_links(self.state)
        mkdir_durable(self.state)
        info = self.state.stat()
        require(info.st_uid == os.getuid() and info.st_mode & 0o077 == 0, 'unsafe_transaction_directory')
        self.lock = os.open(self.state / 'lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        lock_info = os.fstat(self.lock)
        require(lock_info.st_uid == os.getuid() and lock_info.st_nlink == 1 and lock_info.st_mode & 0o077 == 0, 'unsafe_file')
        fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def guard_stopped(self):
        if self.synthetic:
            require(not (self.home / 'app-running').exists(), 'app_running')
            return
        listing = subprocess.run(['/bin/ps', '-axo', 'comm='], capture_output=True, text=True, check=True).stdout
        for line in listing.splitlines():
            command = line.strip()
            if Path(command).name not in ['NanaFlow', 'NanaFocus']:
                continue
            if '/Contents/MacOS/' not in command:
                raise UpgradeError('app_running_or_unverifiable')
            info_path = Path(command.split('/Contents/MacOS/')[0]) / 'Contents/Info.plist'
            try:
                identity = plistlib.loads(info_path.read_bytes()).get('CFBundleIdentifier')
            except Exception:
                raise UpgradeError('app_running_or_unverifiable')
            require(identity != self.bundle, 'app_running')

    def interrupt(self, point):
        if self.args.fault == point:
            print(json.dumps({'ok': False, 'error': 'synthetic_interruption', 'point': point}), flush=True)
            os._exit(75)

    def atomic(self, path, data, point=None, expected_hash=UNSET):
        no_links(path)
        mkdir_durable(path.parent)
        temporary = path.with_name('.' + path.name + '.r1-' + self.transaction + '.tmp')
        if temporary.exists():
            read_file(temporary)  # Never follow or remove a foreign link.
            temporary.unlink()
        if data is None:
            self.guard_stopped()
            require(expected_hash is UNSET or digest(read_file(path)) == expected_hash, 'destination_changed_during_write')
            if path.exists():
                path.unlink()
                fsync_dir(path.parent)
            return
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            with os.fdopen(fd, 'wb') as output:
                if point:
                    output.write(data[:len(data) // 2]); output.flush(); os.fsync(output.fileno())
                    self.interrupt('partial-' + point + '-write')
                    output.write(data[len(data) // 2:])
                else:
                    output.write(data)
                output.flush(); os.fsync(output.fileno())
            self.guard_stopped()
            require(expected_hash is UNSET or digest(read_file(path)) == expected_hash, 'destination_changed_during_write')
            os.replace(temporary, path)
            fsync_dir(path.parent)
            require(digest(read_file(path)) == digest(data), 'write_verification_failed')
        finally:
            if temporary.exists():
                temporary.unlink()

    def save_journal(self):
        self.atomic(self.directory / 'journal.json', json.dumps(self.journal, sort_keys=True, indent=2).encode())

    def verified(self, name, expected):
        path = self.directory / name
        value = read_file(path)
        require(value is None or path.stat().st_mode & 0o077 == 0, 'backup_not_private')
        require(digest(value) == expected, 'backup_or_plan_hash_mismatch')
        return value

    def prepare(self):
        self.transaction = str(uuid.uuid4())
        self.directory = self.state / self.transaction
        no_links(self.directory)
        mkdir_durable(self.directory)
        legacy, target = read_file(self.legacy), read_file(self.target)
        require(legacy is not None, 'legacy_snapshot_missing')
        result = merge(decode_plist(legacy), decode_plist(target))
        candidate = plistlib.dumps(result, fmt=plistlib.FMT_BINARY, sort_keys=True)
        self.atomic(self.directory / 'legacy-before.plist', legacy)
        if target is not None:
            self.atomic(self.directory / 'target-before.plist', target)
        self.atomic(self.directory / 'candidate.plist', candidate)
        self.atomic(self.directory / 'helper-snapshot.py', Path(__file__).read_bytes())
        self.journal = {'schema': 1, 'bundle': self.bundle, 'transaction': self.transaction, 'state': 'prepared',
                        'helperSHA256': digest(Path(__file__).read_bytes()), 'legacySHA256': digest(legacy),
                        'targetBeforeSHA256': digest(target), 'candidateSHA256': digest(candidate)}
        self.save_journal()
        self.verified('legacy-before.plist', self.journal['legacySHA256'])
        self.verified('target-before.plist', self.journal['targetBeforeSHA256'])
        return self.receipt()

    def load(self):
        try:
            self.transaction = str(uuid.UUID(self.args.transaction))
        except (ValueError, TypeError, AttributeError):
            raise UpgradeError('transaction_required')
        require(self.transaction == self.args.transaction, 'invalid_transaction')
        self.directory = self.state / self.transaction
        no_links(self.directory)
        directory_info = self.directory.stat()
        require(directory_info.st_uid == os.getuid() and directory_info.st_mode & 0o077 == 0, 'unsafe_transaction_directory')
        raw = read_file(self.directory / 'journal.json')
        require(raw is not None, 'transaction_missing')
        self.journal = decode_json(raw, dict)
        require(self.journal.get('schema') == 1 and self.journal.get('bundle') == self.bundle
                and self.journal.get('transaction') == self.transaction, 'invalid_journal')
        require(self.journal.get('state') in ['prepared', 'applying', 'applied', 'rolling_back', 'rolled_back'], 'invalid_journal')
        for key in ['helperSHA256', 'legacySHA256', 'candidateSHA256', 'targetBeforeSHA256']:
            value = self.journal.get(key)
            require((key == 'targetBeforeSHA256' and value is None) or
                    (isinstance(value, str) and len(value) == 64 and all(c in '0123456789abcdef' for c in value)), 'invalid_journal')
        require(self.journal.get('helperSHA256') == digest(Path(__file__).read_bytes()), 'helper_version_changed')
        decode_plist(self.verified('legacy-before.plist', self.journal['legacySHA256']))
        decode_plist(self.verified('target-before.plist', self.journal['targetBeforeSHA256']))
        decode_plist(self.verified('candidate.plist', self.journal['candidateSHA256']))
        self.verified('helper-snapshot.py', self.journal['helperSHA256'])

    def apply(self):
        guard_runtime_restore('apply', self.synthetic)
        require(self.args.confirm_bundle_id == self.bundle, 'explicit_bundle_confirmation_required')
        require(self.journal['state'] in ['prepared', 'applying', 'applied'], 'invalid_transaction_state')
        self.guard_stopped()
        require(digest(read_file(self.legacy)) == self.journal['legacySHA256'], 'legacy_changed_prepare_again')
        current = digest(read_file(self.target))
        require(current in [self.journal['targetBeforeSHA256'], self.journal['candidateSHA256']], 'target_changed_prepare_again')
        if self.journal['state'] == 'applied':
            require(current == self.journal['candidateSHA256'], 'target_changed_after_upgrade')
            return self.receipt()
        self.journal['state'] = 'applying'; self.save_journal()
        if current != self.journal['candidateSHA256']:
            self.atomic(self.target, self.verified('candidate.plist', self.journal['candidateSHA256']), 'target', current)
        self.interrupt('after-target-replace')
        self.journal['state'] = 'applied'; self.save_journal()
        return self.receipt()

    def rollback(self):
        guard_runtime_restore('rollback', self.synthetic)
        require(self.args.confirm_bundle_id == self.bundle, 'explicit_bundle_confirmation_required')
        require(self.journal['state'] in ['applying', 'applied', 'rolling_back', 'rolled_back'], 'invalid_transaction_state')
        self.guard_stopped()
        if self.journal['state'] == 'rolled_back':
            return self.verify()
        if self.journal['state'] != 'rolling_back':
            legacy, target = read_file(self.legacy), read_file(self.target)
            require(legacy is not None, 'rollback_legacy_snapshot_missing')
            legacy_value, target_value = decode_plist(legacy), decode_plist(target)
            before_target = self.verified('target-before.plist', self.journal['targetBeforeSHA256'])
            target_unchanged = digest(target) == self.journal['candidateSHA256']
            interrupted_before_apply = self.journal['state'] == 'applying' and digest(target) == self.journal['targetBeforeSHA256']
            if target_unchanged or interrupted_before_apply:
                desired = {'legacy': legacy, 'target': before_target}
            else:
                # Retain post-upgrade sessions/tags in BOTH stores so the old
                # unsandboxed binary can see them after a downgrade.
                candidate = decode_plist(self.verified('candidate.plist', self.journal['candidateSHA256']))
                desired = {'legacy': plistlib.dumps(rollback_merge(legacy_value, target_value, candidate), fmt=plistlib.FMT_BINARY),
                           'target': plistlib.dumps(rollback_merge(decode_plist(before_target), target_value, candidate), fmt=plistlib.FMT_BINARY)}
            self.journal['rollback'] = {}
            for role, old in [('legacy', legacy), ('target', target)]:
                if old is not None:
                    self.atomic(self.directory / ('pre-rollback-' + role + '.plist'), old)
                if desired[role] is not None:
                    self.atomic(self.directory / ('restore-' + role + '.plist'), desired[role])
                self.journal['rollback'][role] = {'beforeSHA256': digest(old), 'desiredSHA256': digest(desired[role])}
            self.journal['state'] = 'rolling_back'; self.save_journal()
        # Legacy first ensures downgrade data survives interruption before the
        # sandbox store is restored. Each step is hash-guarded and resumable.
        for role, path in [('legacy', self.legacy), ('target', self.target)]:
            plan = self.journal['rollback'][role]
            self.verified('pre-rollback-' + role + '.plist', plan['beforeSHA256'])
            current = digest(read_file(path))
            require(current in [plan['beforeSHA256'], plan['desiredSHA256']], 'rollback_input_changed')
            data = self.verified('restore-' + role + '.plist', plan['desiredSHA256'])
            if current != plan['desiredSHA256']:
                self.atomic(path, data, 'rollback-' + role, current)
            if role == 'legacy':
                self.interrupt('after-rollback-legacy-replace')
        self.journal['state'] = 'rolled_back'; self.save_journal()
        return self.receipt()

    def verify(self):
        legacy, target = read_file(self.legacy), read_file(self.target)
        decode_plist(legacy); decode_plist(target)
        state = self.journal['state']
        if state == 'prepared':
            require(digest(legacy) == self.journal['legacySHA256'] and digest(target) == self.journal['targetBeforeSHA256'], 'prepared_inputs_changed')
        if state == 'rolled_back':
            for role, data in [('legacy', legacy), ('target', target)]:
                require(digest(data) == self.journal['rollback'][role]['desiredSHA256'], 'rollback_verification_failed')
        receipt = self.receipt()
        receipt['recoveryRequired'] = state in ['applying', 'rolling_back']
        receipt['targetChangedSinceApply'] = state == 'applied' and digest(target) != self.journal['candidateSHA256']
        return receipt

    def receipt(self):
        return {'ok': True, 'action': self.args.action, 'transaction': self.transaction, 'state': self.journal['state'],
                'legacySHA256': digest(read_file(self.legacy)), 'targetSHA256': digest(read_file(self.target)),
                'candidateSHA256': self.journal['candidateSHA256'], 'synthetic': self.synthetic}

def main():
    class PrivateArgumentParser(argparse.ArgumentParser):
        def error(self, message):
            self.exit(2, '{"ok":false,"error":"invalid_arguments"}\n')
    parser = PrivateArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', default='prepare', choices=['prepare', 'verify', 'apply', 'rollback'])
    parser.add_argument('--bundle-id')
    parser.add_argument('--synthetic-root')
    parser.add_argument('--transaction')
    parser.add_argument('--confirm-bundle-id')
    parser.add_argument('--fault', choices=['partial-target-write', 'after-target-replace',
                        'partial-rollback-legacy-write', 'partial-rollback-target-write', 'after-rollback-legacy-replace'])
    args = parser.parse_args()
    try:
        # Reject production restore before home/path resolution, state creation,
        # input reads, process enumeration, or even the updater umask change.
        guard_runtime_restore(args.action, args.synthetic_root is not None)
        os.umask(0o077)
        upgrader = Upgrader(args)
        if args.action != 'prepare':
            upgrader.load()
        result = getattr(upgrader, args.action)()
        print(json.dumps(result, sort_keys=True))
        return 0
    except UpgradeError as error:
        print(json.dumps({'ok': False, 'error': str(error)}))
    except BlockingIOError:
        print(json.dumps({'ok': False, 'error': 'another_upgrade_is_running'}))
    except Exception:
        # No raw data, paths, keys, token values, or exception text in logs.
        print(json.dumps({'ok': False, 'error': 'offline_operation_failed'}))
    return 2

if __name__ == '__main__':
    sys.exit(main())
