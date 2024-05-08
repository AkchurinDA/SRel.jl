"""
    SensitivityProblem <: AbstractReliabilityProblem

Type used to define sensitivity problems.

$(TYPEDFIELDS)
"""
mutable struct SensitivityProblem <: AbstractReliabilityProblem
    "Random vector ``\\vec{X}``"
    X   ::AbstractVector{<:Distributions.UnivariateDistribution}
    "Correlation matrix ``\\rho^{X}``"
    ρˣ  ::AbstractMatrix{<:Real}
    "Limit state function ``g(\\vec{X}, \\vec{\\Theta_{g}})``"
    g   ::Function
    "Parameters of limit state function ``\\vec{\\Theta_{g}}``"
    Θ   ::AbstractVector{<:Real}
end

"""
    SensitivityProblemCache

Type used to store results of reliability analysis performed using Mean-Centered First-Order Second-Moment (MCFOSM) method.

$(TYPEDFIELDS)
"""
struct SensitivityProblemCache
    "Results of reliability analysis performed using First-Order Reliability Method (FORM)"
    FORMSolution    ::iHLRFCache
    "Sensivity vector of reliability index ``\\vec{\\nabla}_{\\vec{\\Theta_{g}}} \\beta``"
    ∇β              ::Vector{Float64}
    "Sensivity vector of probability of failure ``\\vec{\\nabla}_{\\vec{\\Theta_{g}}} P_{f}``"
    ∇PoF            ::Vector{Float64}
end

"""
    solve(Problem::SensitivityProblem)

Function used to solve sensitivity problems.
"""
function solve(Problem::SensitivityProblem)
    # Extract the problem data:
    X   = Problem.X
    ρˣ  = Problem.ρˣ
    g   = Problem.g
    Θ   = Problem.Θ

    # Define a reliability problem for the FORM analysis:
    g₁(x) = g(x, Θ)
    FORMProblem = ReliabilityProblem(X, ρˣ, g₁)

    # Solve the reliability problem using the FORM:
    FORMSolution = solve(FORMProblem, FORM())
    x            = FORMSolution.x[:, end]
    u            = FORMSolution.u[:, end]
    β            = FORMSolution.β

    # Perform Nataf transformation:
    NatafObject = NatafTransformation(X, ρˣ)

    # Define gradient functions of the limit state function in X- and U-spaces:
    ∇g(x, Θ) = ForwardDiff.gradient(Unknown -> g(x, Unknown), Θ)
    ∇G(u, Θ) = ForwardDiff.gradient(Unknown -> G(g, Θ, NatafObject, Unknown), u)
    
    # Compute the sensitivities w.r.t. the reliability index:
    ∇β = ∇g(x, Θ) / LinearAlgebra.norm(∇G(u, Θ))

    # Compute the sensitivities w.r.t. the probability of failure:
    ∇PoF = -Distributions.pdf(Distributions.Normal(), β) * ∇β

    return SensitivityProblemCache(FORMSolution, ∇β, ∇PoF)
end

function G(g::Function, θ::AbstractVector, NatafObject::NatafTransformation, USample::AbstractVector)
    # Transform samples:
    XSample = transformsamples(NatafObject, USample, "U2X")

    # Evaluate the limit state function at the transform samples:
    GSample = g(XSample, θ)

    # Return the result:
    return GSample
end