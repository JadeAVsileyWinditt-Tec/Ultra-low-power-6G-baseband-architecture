"""
Core mathematical implementation of the Topological Boundary Unit (TBU).

Reference: "The Topological Boundary Unit (TBU): A Unified Mathematical
Framework for Boundary-State Dynamics" – Jade Siley-Winditt, 2026.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto
from typing import Callable, Optional, Tuple

import numpy as np


class Region(Enum):
    BOUND = auto()          # Ω_int  – captured / power-gated
    BOUNDARY = auto()       # ∂Ω_δ  – transition layer
    FREE = auto()           # Ω_ext  – radiative / high-throughput


@dataclass(frozen=True)
class TBUParams:
    """
    Parameters of a Topological Boundary Unit instance.

    For the 6G silicon pillar:
        S_crit ≈ 4.0 W (thermal envelope)
        δ controls the softness of the thermal throttle
        K scales the strength of the containment (power-gating) force
    """
    S_crit: float = 4.0          # critical action potential (W for silicon)
    delta: float = 0.15          # boundary layer thickness
    K: float = 8.0               # containment tensor magnitude (scalar for 1-D)

    def __post_init__(self):
        if self.delta <= 0:
            raise ValueError("Boundary thickness δ must be positive")


def boundary_measure(S: float | np.ndarray, params: TBUParams) -> float | np.ndarray:
    """
    Smooth state measure B_δ(x) ∈ [0, 1].

    B_δ = 1 / (1 + exp( −(S − S_crit) / δ ))

    → 0 deep in the bound region, → 1 deep in the free region,
    = 0.5 exactly on the critical hypersurface.
    """
    return 1.0 / (1.0 + np.exp(-(S - params.S_crit) / params.delta))


def classify_region(S: float, params: TBUParams) -> Region:
    """Map a scalar action potential into one of the three topological regions."""
    if S < params.S_crit - params.delta:
        return Region.BOUND
    if S > params.S_crit + params.delta:
        return Region.FREE
    return Region.BOUNDARY


def boundary_entropy(S: float | np.ndarray, params: TBUParams) -> float | np.ndarray:
    """
    Local topological entropy H_δ(S).

    H = −p ln p − (1−p) ln(1−p)  with p = B_δ(S)

    Maximum value ln(2) is attained exactly at S = S_crit.
    """
    p = np.clip(boundary_measure(S, params), 1e-12, 1.0 - 1e-12)
    return -p * np.log(p) - (1.0 - p) * np.log(1.0 - p)


def containment_force(
    S: float | np.ndarray,
    grad_S: float | np.ndarray,
    params: TBUParams,
) -> float | np.ndarray:
    """
    Non-conservative containment term:  −K · [1 − B_δ(S)] · ∇S

    Inside the free region B≈1 → force ≈ 0.
    Deep in the bound region B≈0 → full containment −K ∇S.
    """
    B = boundary_measure(S, params)
    return -params.K * (1.0 - B) * grad_S


def integrate_dynamics(
    x0: np.ndarray,
    F: Callable[[np.ndarray], np.ndarray],
    S_fn: Callable[[np.ndarray], float],
    grad_S_fn: Callable[[np.ndarray], np.ndarray],
    params: TBUParams,
    t_span: Tuple[float, float] = (0.0, 1.0),
    dt: float = 1e-3,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Simple fixed-step Euler integration of the universal TBU field equation

        dx/dt = F(x) − K · [1 − B_δ(S(x))] ∇S(x)

    Returns (times, trajectory).
    """
    t0, t1 = t_span
    n_steps = max(1, int(np.ceil((t1 - t0) / dt)))
    times = np.linspace(t0, t1, n_steps + 1)
    traj = np.zeros((n_steps + 1, x0.shape[0]))
    traj[0] = x0

    x = x0.copy()
    for i in range(n_steps):
        S = S_fn(x)
        gS = grad_S_fn(x)
        dx = F(x) + containment_force(S, gS, params)
        x = x + dt * dx
        traj[i + 1] = x

    return times, traj


# Convenience 1-D specialisation used by the power model
def thermal_throttle_factor(power_W: float, params: TBUParams) -> float:
    """
    Returns a multiplicative throttle ∈ [0, 1] derived from the
    boundary measure.  Used by the silicon power controller.

    throttle = B_δ(power)   → 1.0 when comfortably under the envelope,
                               → 0.0 when deep over the thermal limit.
    """
    return float(boundary_measure(power_W, params))
