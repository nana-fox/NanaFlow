import AppKit
import SwiftUI

/// Transparent native hit regions over noninteractive parts of the compact UI.
/// Hosting views can consume background drags, so track actual mouse events.
struct WindowDragSurface: NSViewRepresentable {
    let regions: [CGRect]

    static func regions(in bounds: CGRect, excluding exclusions: [CGRect]) -> [CGRect] {
        exclusions.reduce([bounds]) { regions, excluded in
            regions.flatMap { region -> [CGRect] in
                let cut = region.intersection(excluded)
                guard !cut.isNull, !cut.isEmpty else { return [region] }
                return [
                    CGRect(x: region.minX, y: region.minY, width: region.width, height: cut.minY - region.minY),
                    CGRect(x: region.minX, y: cut.maxY, width: region.width, height: region.maxY - cut.maxY),
                    CGRect(x: region.minX, y: cut.minY, width: cut.minX - region.minX, height: cut.height),
                    CGRect(x: cut.maxX, y: cut.minY, width: region.maxX - cut.maxX, height: cut.height)
                ].filter { !$0.isEmpty }
            }
        }
    }

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.regions = regions
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.regions = regions
    }

    final class DragView: NSView {
        var regions: [CGRect] = []
        private var startPoint: NSPoint?
        private var startOrigin: NSPoint?
        private var coordinateSource: CoordinateSource?

        enum CoordinateSource { case event, pointer }

        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            guard bounds.contains(local),
                  NSBezierPath(roundedRect: bounds, xRadius: 26, yRadius: 26).contains(local),
                  regions.contains(where: { $0.contains(local) }) else { return nil }
            return self
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            coordinateSource = event.cgEvent == nil ? .pointer : .event
            startPoint = screenPoint(for: event)
            startOrigin = window.frame.origin
            window.makeKeyAndOrderFront(nil)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let startPoint, let startOrigin,
                  let point = screenPoint(for: event) else { return }
            window.setFrameOrigin(Self.origin(start: startOrigin, anchor: startPoint, point: point))
        }

        override func mouseUp(with event: NSEvent) {
            startPoint = nil
            startOrigin = nil
            coordinateSource = nil
        }

        private func screenPoint(for event: NSEvent) -> NSPoint? {
            guard let coordinateSource else { return nil }
            return Self.screenPoint(quartz: event.cgEvent?.location,
                                    pointer: NSEvent.mouseLocation,
                                    source: coordinateSource)
        }

        static func screenPoint(quartz: CGPoint?, pointer: NSPoint, source: CoordinateSource) -> NSPoint? {
            switch source {
            case .event:
                // Keep one coordinate source for the entire gesture. Missing a
                // queued CGEvent skips that sample instead of changing origins.
                guard let quartz else { return nil }
                return NSPoint(x: quartz.x, y: -quartz.y)
            case .pointer:
                return pointer
            }
        }

        static func origin(start: NSPoint, anchor: NSPoint, point: NSPoint) -> NSPoint {
            NSPoint(x: start.x + point.x - anchor.x, y: start.y + point.y - anchor.y)
        }
    }
}
