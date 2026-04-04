# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-03

### Added
- Token bucket rate limiting algorithm with configurable capacity, refill rate, and cost
- Sliding window rate limiting algorithm with configurable limit and window size
- ETS-backed storage for high-performance concurrent access
- GenServer-managed lifecycle with automatic cleanup of stale entries
- `check/3` for atomic check-and-consume operations
- `peek/3` for non-consuming status checks
- `status/3` for direct info map access
- `reset/2` and `reset_all/1` for clearing rate limit state
- Multi-key support for rate limiting by any identifier
- Supervision tree compatible via `child_spec/1`
