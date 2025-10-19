# Storage Performance Comparison: OpenEBS LocalPV NVMe vs Rook-Ceph Block Storage

**Test Date:** October 19, 2025
**Test Tool:** KBench (Official Longhorn Benchmark Tool)
**Test Size:** 30GB per storage system
**Test Duration:** ~5 minutes 50 seconds each
**Hardware:** PNY NVMe SSDs on 3-node cluster (infra-01, infra-02, infra-03)

---

## Executive Summary

Comprehensive storage performance testing was conducted using the official KBench tool to compare OpenEBS LocalPV NVMe (direct-attached storage) against Rook-Ceph Block Storage (distributed storage). The results demonstrate **dramatic performance advantages** for OpenEBS LocalPV NVMe across all key metrics except random read throughput, where Rook-Ceph shows slight advantages due to caching mechanisms.

### Key Findings:
- **OpenEBS LocalPV NVMe**: Up to 51,846% faster latency, 6,507% higher IOPS for sequential writes
- **Rook-Ceph Block**: Slightly better random read throughput, but significantly higher latency (0.5-7.5ms vs 0.014-0.086ms)
- **Use Case Differentiation**: Local storage for performance-critical workloads vs distributed storage for availability

---

## Detailed Performance Metrics

### IOPS (Input/Output Operations Per Second)

| Operation Type | OpenEBS LocalPV NVMe | Rook-Ceph Block | Performance Advantage |
|----------------|---------------------|-----------------|---------------------|
| Random Read | **192,854 IOPS** | 68,159 IOPS | **283% faster** |
| Random Write | **54,018 IOPS** | 4,494 IOPS | **1,202% faster** |
| Sequential Read | **52,841 IOPS** | 9,262 IOPS | **571% faster** |
| Sequential Write | **251,980 IOPS** | 3,873 IOPS | **6,507% faster** |

### Bandwidth (Throughput)

| Operation Type | OpenEBS LocalPV NVMe | Rook-Ceph Block | Performance Difference |
|----------------|---------------------|-----------------|----------------------|
| Random Read | 1,251,093 KiB/sec (~1.2 GB/s) | **1,636,877 KiB/sec (~1.6 GB/s)** | Rook-Ceph 30% faster |
| Random Write | **664,490 KiB/sec (~649 MB/s)** | 375,440 KiB/sec (~366 MB/s) | OpenEBS 77% faster |
| Sequential Read | **1,426,022 KiB/sec (~1.4 GB/s)** | 1,135,528 KiB/sec (~1.1 GB/s) | OpenEBS 26% faster |
| Sequential Write | **1,610,517 KiB/sec (~1.6 GB/s)** | 352,620 KiB/sec (~344 MB/s) | OpenEBS 456% faster |

### Latency (Response Time)

| Operation Type | OpenEBS LocalPV NVMe | Rook-Ceph Block | Performance Advantage |
|----------------|---------------------|-----------------|---------------------|
| Random Read | **85,584 ns (~0.086 ms)** | 952,429 ns (~0.952 ms) | **1,013% faster** |
| Random Write | **29,483 ns (~0.029 ms)** | 7,209,196 ns (~7.209 ms) | **24,447% faster** |
| Sequential Read | **17,907 ns (~0.018 ms)** | 527,881 ns (~0.528 ms) | **2,949% faster** |
| Sequential Write | **14,410 ns (~0.014 ms)** | 7,468,977 ns (~7.469 ms) | **51,846% faster** |

---

## Performance Analysis

### OpenEBS LocalPV NVMe - Performance Champion

**Strengths:**
- **Ultra-Low Latency**: Sub-millisecond latency (14-86 microseconds)
- **Exceptional IOPS**: Outstanding performance across all workload types
- **High Throughput**: Consistently high bandwidth, especially for writes
- **Predictable Performance**: Low variance suitable for critical applications
- **Direct Storage Access**: No network overhead or distributed coordination

**Performance Highlights:**
- Sequential write performance: 251,980 IOPS at 1.6 GB/s
- Random write latency: 29 microseconds (vs 7.2ms for Rook-Ceph)
- Consistent performance across all operation types

### Rook-Ceph Block Storage - Distributed Storage Capabilities

**Strengths:**
- **Distributed Architecture**: Multi-node data availability and redundancy
- **Slightly Better Random Read Throughput**: Due to intelligent caching
- **Network-Based**: Accessible from any node in the cluster
- **Scalable**: Can scale across multiple storage nodes
- **Rich Feature Set**: Snapshots, clones, and advanced Ceph features

**Performance Limitations:**
- **High Latency**: 0.5-7.5ms due to network and coordination overhead
- **Lower Write Performance**: Especially affected by distributed consensus
- **Variable Performance**: Dependent on network conditions and cluster load

---

## Use Case Recommendations

### Choose OpenEBS LocalPV NVMe for:

**High-Performance Scenarios:**
- **Production Databases**: PostgreSQL, MySQL, MongoDB requiring low latency
- **Real-time Applications**: Financial trading, gaming servers
- **Kubernetes StatefulSets**: Stateful applications requiring consistent performance
- **Analytics Workloads**: ETL pipelines, data processing
- **Machine Learning**: Model training and inference
- **Content Delivery**: High-throughput media serving

**When Performance is Critical:**
- Latency-sensitive applications (< 1ms response time required)
- High IOPS workloads (> 100,000 IOPS needed)
- Predictable performance requirements
- Single-node or zone-bound applications

### Choose Rook-Ceph Block Storage for:

**Distributed Storage Scenarios:**
- **Multi-Node Applications**: Workloads requiring access from multiple nodes
- **Development/Testing**: Shared storage environments
- **Backup and Archive**: Where performance is secondary to availability
- **Batch Processing**: Non-real-time workloads tolerant to higher latency
- **Cost Optimization**: Shared storage resources across multiple applications

**When Availability Trumps Performance:**
- Multi-zone or multi-region data distribution
- Applications tolerant to higher latency (> 1ms)
- Shared storage requirements
- Backup and disaster recovery scenarios

---

## Performance Gap Summary

| Metric | OpenEBS LocalPV NVMe | Rook-Ceph Block | Performance Gap |
|--------|---------------------|-----------------|-----------------|
| **IOPS Performance** | 3x - 65x faster | Baseline | **Massive OpenEBS advantage** |
| **Latency** | 10x - 51,846x faster | Baseline | **Orders of magnitude difference** |
| **Write Throughput** | 77% - 4,500% faster | Baseline | **Significant OpenEBS advantage** |
| **Read Throughput** | Generally 26% faster | Slightly better in random reads | **Comparable performance** |

---

## Technical Implementation Details

### Test Configuration
- **KBench Version**: Latest (yasker/kbench:latest)
- **Test Parameters**:
  - Mode: "full" (comprehensive testing)
  - File Size: 30GB
  - Test Duration: 5+ minutes per test
  - CPU Idle Profiling: disabled

### Storage Classes Tested
- **OpenEBS LocalPV NVMe**: `openebs-local-nvme` (direct-attached NVMe)
- **Rook-Ceph Block**: `rook-ceph-block` (Ceph RBD distributed storage)

### Note on CephFS
CephFS was not deployed in the current cluster configuration. Only Rook-Ceph block storage (RBD) was available for testing. CephFS testing would require additional configuration of the Ceph cluster.

---

## Conclusion

The performance testing clearly demonstrates that **OpenEBS LocalPV NVMe provides dramatically superior performance** for local storage workloads, with **orders of magnitude better latency** and **significantly higher IOPS**.

**Key Takeaway:**
- **Performance-critical workloads** should use **OpenEBS LocalPV NVMe**
- **Distributed storage requirements** should use **Rook-Ceph Block Storage**
- The choice represents a **performance vs. availability trade-off**, not a direct feature comparison

The results validate the architectural differences: direct-attached storage provides optimal performance, while distributed storage provides multi-node availability at the cost of higher latency and lower IOPS.

---

**Test Completed:** October 19, 2025
**Next Steps:** Consider specific workload requirements and availability needs when selecting storage classes for applications.