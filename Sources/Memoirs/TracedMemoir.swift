//
// TracedMemoir
// Memoirs
//
// Created by Alex Babaev on 22 May 2021.
// Copyright © 2021 Alex Babaev. All rights reserved.
// License: MIT License, https://github.com/redmadrobot-spb/memoirs-ios/blob/main/LICENSE
//

import Foundation
import Synchronization

public final class TracedMemoir: Memoir, Sendable {
    private let state: Mutex<Tracer>
    private let parent: TracedMemoir?
    private let memoir: any Memoir
    private let initTracer: Tracer?
    private let managesLifecycle: Bool

    public var tracer: Tracer {
        state.withLock { $0 }
    }

    public var tracers: [Tracer] {
        allTracers
    }

    private var allTracers: [Tracer] {
        var result = [state.withLock { $0 }]
        var current = parent
        while let p = current {
            result.append(p.state.withLock { $0 })
            current = p.parent
        }
        return result
    }

    private init(tracer: Tracer, parent: TracedMemoir?, memoir: any Memoir) {
        self.initTracer = tracer
        self.state = Mutex(tracer)
        self.parent = parent
        self.memoir = memoir
        self.managesLifecycle = false
    }

    public init(
        tracer: Tracer, meta: [String: SafeString] = [:], memoir: Memoir,
        file: String = #fileID, function: String = #function, line: UInt = #line
    ) {
        initTracer = tracer
        state = Mutex(tracer)

        if let parentMemoir = memoir as? TracedMemoir {
            self.parent = parentMemoir
            self.memoir = parentMemoir.memoir
        } else {
            self.parent = nil
            self.memoir = memoir
        }

        managesLifecycle = true
        self.memoir.update(tracer: tracer, meta: meta, tracers: allTracers, file: file, function: function, line: line)
    }

    public convenience init(
        label: String, memoir: Memoir,
        file: String = #fileID, function: String = #function, line: UInt = #line
    ) {
        self.init(
            tracer: .label(label), meta: [:], memoir: memoir,
            file: file, function: function, line: line
        )
    }

    public convenience init(
        object: Any, memoir: Memoir,
        file: String = #fileID, function: String = #function, line: UInt = #line
    ) {
        let tracer = Memoirs.tracer(for: object)
        self.init(
            tracer: tracer, meta: [:], memoir: memoir,
            file: file, function: function, line: line
        )
    }

    public func with(tracer: Tracer) -> TracedMemoir {
        TracedMemoir(tracer: tracer, parent: self, memoir: memoir)
    }

    public func withUnique(tracer: Tracer) -> TracedMemoir {
        if initTracer == tracer {
            self
        } else {
            self.with(tracer: tracer)
        }
    }

    public func updateTracer(to tracer: Tracer) {
        state.withLock { $0 = tracer }
    }

    public func append(
        _ item: MemoirItem, message: @autoclosure () throws -> SafeString,
        meta: @autoclosure () -> [String: SafeString]?, tracers: [Tracer], timeIntervalSinceReferenceDate: TimeInterval,
        file: String, function: String, line: UInt
    ) rethrows {
        let selfTracers = allTracers
        try memoir.append(
            item, message: message(), meta: meta(), tracers: tracers + selfTracers,
            timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate,
            file: file, function: function, line: line
        )
    }

    deinit {
        if managesLifecycle {
            let tracer = state.withLock { $0 }
            let tracers = allTracers
            memoir.finish(tracer: tracer, tracers: tracers)
        }
    }
}
