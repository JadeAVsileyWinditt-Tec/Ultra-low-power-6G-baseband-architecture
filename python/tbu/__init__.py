"""
Topological Boundary Unit (TBU) – core mathematical primitives.

Implements the continuous state measure, universal dynamics,
boundary entropy, and region classification defined in the
TBU research notes (Jade Siley-Winditt, 2026).
"""

from .core import (
    TBUParams,
    boundary_measure,
    classify_region,
    boundary_entropy,
    containment_force,
    integrate_dynamics,
)

__all__ = [
    "TBUParams",
    "boundary_measure",
    "classify_region",
    "boundary_entropy",
    "containment_force",
    "integrate_dynamics",
]
