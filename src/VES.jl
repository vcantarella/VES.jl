module VES

using SpecialFunctions
using LinearAlgebra
using QuadGK
using FastGaussQuadrature

# Export the main functions
export kern1d, pot1d, wenner_apparent_resistivity, apparent_resistivity, create_integration_points

"""
Kernel function for 1D VES model using the GIMLI implementation approach.
This works from the bottom layer upward, which is more numerically stable.
"""
function kern1d(λ::Vector{<:Real}, ρ::Vector{<:Real}, h::Vector{<:Real})
    nr = length(ρ)
    nl = length(λ)
    
    # Special case for homogeneous half-space
    if nr == 1 && isempty(h)
        return zeros(nl)  # For homogeneous half-space, kernel = 0
    end
    
    # Start with bottom layer resistivity
    z = fill(ρ[nr], nl)
    p = zeros(nl)
    
    # Work upward from the bottom layer
    for i in nr-1:-1:1
        p = (z .- ρ[i]) ./ (z .+ ρ[i])
        th = tanh.(λ .* h[i])
        z = ρ[i] .* (z .+ th .* ρ[i]) ./ (z .* th .+ ρ[i])
    end
    
    # Final calculation
    ehl = exp.(-2.0 .* λ .* h[1]) .* p
    return ehl ./ (1.0 .- ehl) .* ρ[1] / (2.0 * π)
end

"""
Calculate potential at distance R using efficient Gauss-Kronrod quadrature
with pre-computed weights and abscissae
"""
function pot1d(R::Vector{<:Real}, ρ::Vector{<:Real}, h::Vector{<:Real}, myx, myw)
    z0 = zeros(length(R))
    
    for i in 1:length(R)
        rabs = abs(R[i])
        # Scale the integration points by 1/rabs
        λ = myx ./ rabs
        z0[i] = sum(myw .* kern1d(λ, ρ, h) .* 2.0) / rabs
    end
    
    return z0
end

"""
Calculate apparent resistivity for Wenner array
"""
function wenner_apparent_resistivity(a::Real, ρ::Vector{<:Real}, h::Vector{<:Real}, myx, myw)
    # For Wenner array with spacing a
    am = a        # A-M distance
    an = 2*a      # A-N distance
    bm = 2*a      # B-M distance
    bn = a        # B-N distance
    
    # Geometric factor for Wenner
    k = 2.0 * π / (1.0/am - 1.0/an - 1.0/bm + 1.0/bn)
    
    # Calculate potentials
    pot_am = pot1d([am], ρ, h, myx, myw)
    pot_an = pot1d([an], ρ, h, myx, myw)
    pot_bm = pot1d([bm], ρ, h, myx, myw)
    pot_bn = pot1d([bn], ρ, h, myx, myw)
    
    # Final calculation
    return (pot_am[1] - pot_an[1] - pot_bm[1] + pot_bn[1]) * k + ρ[1]
end

"""
Calculate the apparent resistivity from the measured potential difference, current, and geometric factor.

Parameters:
ΔU (Float64): Measured potential difference in volts.
I (Float64): Current in amperes.
G (Float64): Geometric factor.

Returns:
Float64: Apparent resistivity in ohm-meters.
"""
function apparent_resistivity(ΔU, I, G)
    return (ΔU / I) * G
end

"""
Create integration points for numerical integration using Gauss-Legendre quadrature.
This creates points optimized for the (0, ∞) interval using exponential mapping.

Parameters:
n (Int): Number of integration points. Default is 100.

Returns:
Tuple{Vector{Float64}, Vector{Float64}}: Integration points (myx) and weights (myw).
"""
function create_integration_points(n=100)
    # Create Gauss-Legendre points and weights
    x, w = gausslegendre(n)
    
    # Transform to (0, ∞) interval using exponential mapping
    # This gives good coverage of both small and large values
    myx = -log.(0.5 .* (1.0 .- x))
    myw = w ./ (2.0 .* exp.(myx))
    
    return myx, myw
end

end
