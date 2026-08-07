# Topological Boundary Unit (TBU) – Mapping to the 6G Baseband Fabric

**Source document**: *The Topological Boundary Unit (TBU): A Unified Mathematical Framework for Boundary-State Dynamics*, Jade Siley-Winditt, 2026.

## 1. Axiomatic Core (recap)

A system trajectory \(x(t)\) lives on a manifold \(M\) partitioned by the critical hypersurface

\[
\Gamma = \{ x \in M \mid S(x) = S_{\rm crit} \}
\]

with finite boundary-layer thickness \(\delta > 0\):

| Region | Definition | Silicon meaning |
|--------|------------|-----------------|
| \(\Omega_{\rm int}\) (Bound) | \(S < S_{\rm crit}-\delta\) | Power-gated / sub-thermal tiles |
| \(\partial\Omega_\delta\) (Boundary) | \(\lvert S-S_{\rm crit}\rvert\le\delta\) | Dynamic load-balancing / soft throttle |
| \(\Omega_{\rm ext}\) (Free) | \(S > S_{\rm crit}+\delta\) | Full high-throughput streaming |

Smooth state measure:

\[
B_\delta(x) = \frac{1}{1+\exp\bigl(-(S(x)-S_{\rm crit})/\delta\bigr)}
\]

Universal dynamics:

\[
\frac{dx}{dt} = F(x) - K\cdot\bigl[1-B_\delta(x)\bigr]\nabla S(x)
\]

## 2. Silicon Instantiation (Pillar C)

| TBU Concept | 6G Baseband Realisation |
|-------------|-------------------------|
| System vector \(x\) | 2048-dimensional tile state vector \(T\) |
| Action potential \(S\) | Instantaneous total power \(P(T)=\sum P_{\rm tile}\) |
| Critical boundary \(S_{\rm crit}\) | **4 W thermal envelope** |
| Boundary thickness \(\delta\) | Softness of the thermal throttle (typ. 0.15–0.25 W) |
| Containment tensor \(K\) | Strength of the TBCU feedback (gain) |
| Bound state | Aggressive power-gating of tiles |
| Free state | Unrestricted high-throughput data movement |
| Boundary layer | Continuous intensity scaling / load balancing |

The **Thermal Boundary Control Unit (TBCU)** is the hardware embodiment of the containment term. It evaluates \(B_\delta(P)\) and broadcasts a throttle factor to every tile’s local intensity limiter.

## 3. Local Intensity Cap

In addition to the global TBU boundary, each tile is protected by a hard intensity ceiling:

\[
\text{ops per tile} \le 700 \times \text{transistors per tile}
\]

This prevents any single tile from becoming a thermal hotspot even if the global controller is temporarily saturated.

## 4. Entropy & Exceptional Points

Inside \(\partial\Omega_\delta\) the topological entropy

\[
H_\delta = -B\ln B - (1-B)\ln(1-B)
\]

reaches its maximum \(\ln 2\). In the silicon domain this corresponds to the highest rate of dynamic re-allocation of power budget among tiles – exactly where the TBCU is most active.

The edges of the boundary layer (\(\lvert P-4\,\text{W}\rvert=\delta\)) behave as Exceptional Points of the underlying non-Hermitian description: the system can transition abruptly from a propagating (high-throughput) regime into an exponentially decaying (power-gated) regime.

## 5. Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| Pure TBU mathematics | Complete | `python/tbu/` |
| Fabric power model + continuous boundary | Complete | `python/power/` |
| Parameter package | Complete | `rtl/common/params.sv` |
| Per-tile intensity limiter | Complete | `rtl/tile/intensity_limiter.sv` |
| Compute tile wrapper | Complete | `rtl/tile/compute_tile.sv` |
| Thermal Boundary Control Unit | Complete | `rtl/tbc/tbc_unit.sv` |
| Hierarchical NoC | Planned | `rtl/noc/` |
| Full-chip top + cycle-accurate sim | Planned | `rtl/top/`, `sim/` |

## 6. Next Concrete Steps

1. Replace the piecewise-linear \(B_\delta\) approximation inside the TBCU with a compact LUT or polynomial that more closely matches the logistic function.
2. Build a reduction-tree power aggregator so the TBCU receives a real sum of tile activities every epoch.
3. Introduce hierarchical (region-level) throttling so that only hot regions are constrained while cold regions continue at full performance.
4. Couple the approximate-computing ALU units so that intensity reduction also comes from algorithmic pruning, not only from the thermal controller.
5. Close the loop with a SystemVerilog testbench that drives realistic sub-THz traffic patterns and verifies the 4 W envelope under the continuous TBU dynamics.
