/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <benchmark/benchmark.h>
#include <folly/init/Init.h>
#include <stdint.h>
#include <algorithm>
#include <limits>

namespace facebook::eden {

/**
 * Accumulates data points, tracking their average and minimum.
 *
 * This type is a monoid.
 */
class StatAccumulator {
 public:
  void add(uint64_t value) {
    minimum_ = std::min(minimum_, value);
    total_ += value;
    ++count_;
  }

  void combine(StatAccumulator other) {
    minimum_ = std::min(minimum_, other.minimum_);
    total_ += other.total_;
    count_ += other.count_;
  }

  uint64_t getMinimum() const {
    return minimum_;
  }

  uint64_t getAverage() const {
    return count_ ? total_ / count_ : 0;
  }

 private:
  uint64_t minimum_{std::numeric_limits<uint64_t>::max()};
  uint64_t total_{0};
  uint64_t count_{0};
};

/**
 * Returns the current time in nanoseconds since some epoch. A fast timer
 * suitable for benchmarking short operations.
 */
uint64_t getTime() noexcept;

/**
 * Calls getTime several times and computes its average and minimum execution
 * times. Benchmarks that measure the cost of extremely fast operations
 * (nanoseconds) should print the clock overhead as well so the results can be
 * interpreted more accurately.
 */
StatAccumulator measureClockOverhead() noexcept;

} // namespace facebook::eden

#define EDEN_BENCHMARK_MAIN()                                 \
  int main(int argc, char** argv) {                           \
    ::benchmark::Initialize(&argc, argv);                     \
    folly::init(&argc, &argv);                                \
    if (::benchmark::ReportUnrecognizedArguments(argc, argv)) \
      return 1;                                               \
    ::benchmark::RunSpecifiedBenchmarks();                    \
  }                                                           \
  int main(int, char**)
