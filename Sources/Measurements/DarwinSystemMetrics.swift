//
// DarwinSystemMetrics
// Memoirs
//
// Created by Alex Babaev on 05 June 2021.
// Copyright © 2021 Alex Babaev. All rights reserved.
// License: MIT License, https://github.com/redmadrobot-spb/memoirs-ios/blob/main/LICENSE
//

#if canImport(Darwin)

import Foundation
import Darwin
import MemoirsWorkaroundC

final class DarwinSystemMetrics: MetricsRetriever {
    private let keyCPUUsagePercent: String = "cpuUsagePercent"
    private let keyMemoryUsageValue: String = "memoryUsageValue"

    private let basicInfoCount = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size /  MemoryLayout<UInt32>.size)
    private let vmInfoCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<UInt32>.size)

    private final class MachPortHolder: @unchecked Sendable {
        static var value: mach_port_t { workaroundMachTaskSelf() }
    }

    private func cpuUsage() -> Double? {
        var threadCount: mach_msg_type_number_t = 0
        var threadsArray: thread_act_array_t?
        guard task_threads(MachPortHolder.value, &threadsArray, &threadCount) == KERN_SUCCESS else { return nil }
        guard let threads = threadsArray else { return nil }

        defer {
            let size = MemoryLayout<thread_t>.size * Int(threadCount)
            // vm_address_t is UInt32 on arm64_32, so the pointer goes through the word-sized UInt.
            let address = vm_address_t(UInt(bitPattern: threads))
            vm_deallocate(MachPortHolder.value, address, vm_size_t(size))
        }

        return (0 ..< Int(threadCount))
            .map { index in
                var info = thread_basic_info()
                var infoCount = basicInfoCount
                let result = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                    }
                }
                guard result == KERN_SUCCESS else { return 0 }

                return info.flags & TH_FLAGS_IDLE == 0 ? Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0 : 0
            }
            .reduce(0.0, +)
    }

    private func memoryUsage() -> Int? {
        var info = task_vm_info_data_t()
        var infoCount = vmInfoCount
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(MachPortHolder.value, thread_flavor_t(TASK_VM_INFO), $0, &infoCount)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return Int(info.internal)
    }

    var calculatedMetrics: [String: MeasurementValue] {
        var result: [String: MeasurementValue] = [:]
        if let cpuUsage = cpuUsage() {
            result[keyCPUUsagePercent] = .double(cpuUsage)
        }
        if let memoryUsage = memoryUsage() {
            result[keyMemoryUsageValue] = .int(Int64(memoryUsage))
        }
        return result
    }
}

#endif
