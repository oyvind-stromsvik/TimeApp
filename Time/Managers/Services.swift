import Foundation
import CoreGraphics

// Abstraction for a timer that fires repeatedly
protocol TimerService {
    var onTick: (() -> Void)? { get set }
    func start(interval: TimeInterval)
    func stop()
}

// Abstraction for system-level queries (idle time)
protocol SystemService {
    func getIdleTime() -> TimeInterval?
}

// Default Implementations

class DefaultTimerService: TimerService {
    var onTick: (() -> Void)?
    private var timer: Timer?
    
    func start(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onTick?()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

class DefaultSystemService: SystemService {
    func getIdleTime() -> TimeInterval? {
        // kCGAnyInputEventType is ~0 (UInt32.max)
        if let eventType = CGEventType(rawValue: UInt32.max) {
             return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: eventType)
        }
        return nil
    }
}
