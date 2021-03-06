# DistributionStat objects
# fit! methods should only update "sufficient statistics"
# value methods should create the distribution

abstract DistributionStat{I<:Input} <: OnlineStat{I}
Base.mean(d::DistributionStat) = mean(value(d))
Base.var(d::DistributionStat) = var(value(d))
Base.std(d::DistributionStat) = std(value(d))
Ds.params(o::DistributionStat) = Ds.params(value(o))
Ds.ncategories(o::DistributionStat) = Ds.ncategories(value(o))
Base.cov(o::DistributionStat) = cov(value(o))


#--------------------------------------------------------------# Beta
type FitBeta{W<:Weight} <: DistributionStat{ScalarInput}
    value::Ds.Beta
    var::Variance{W}
end
FitBeta(wgt::Weight = EqualWeight()) = FitBeta(Ds.Beta(), Variance(wgt))
nobs(o::FitBeta) = nobs(o.var)
fit!(o::FitBeta, y::Real) = (fit!(o.var, y); o)
function value(o::FitBeta)
    if nobs(o) > 1
        m = mean(o.var)
        v = var(o.var)
        α = m * (m * (1 - m) / v - 1)
        β = (1 - m) * (m * (1 - m) / v - 1)
        o.value = Ds.Beta(α, β)
    end
end


#------------------------------------------------------------------# Categorical
# Ignores weight
"""
Find the proportions for each unique input.  Categories are sorted by proportions.
Ignores `Weight`.

```julia
o = FitCategorical(y)
```
"""
type FitCategorical{W<:Weight, T<:Any} <: DistributionStat{ScalarInput}
    value::Ds.Categorical
    d::Dict{T, Int}
    weight::W
end
FitCategorical(wgt::Weight = EqualWeight()) = FitCategorical(Ds.Categorical(1), Dict{Any, Int}(), wgt)
function FitCategorical(y, wgt::Weight = EqualWeight())
    o = FitCategorical()
    fit!(o, y)
    o
end
function fit!(o::FitCategorical, y::Union{Real, AbstractString, Symbol})
    weight!(o, 1)
    if haskey(o.d, y)
        o.d[y] += 1
    else
        o.d[y] = 1
    end
    o
end
sortpairs(o::FitCategorical) = sort(collect(o.d), by = x -> 1 / x[2])
function value(o::FitCategorical)
    if nobs(o) !== 0
        sortedpairs = sortpairs(o)
        counts = zeros(length(sortedpairs))
        for i in 1:length(sortedpairs)
            counts[i] = sortedpairs[i][2]
        end
        o.value = Ds.Categorical(counts / sum(counts))
    end
end
function Base.show(io::IO, o::FitCategorical)
    printheader(io, "FitCategorical ($(length(o.d)) levels)")
    print_item(io, "value", value(o))
    sortedpairs = sortpairs(o)
    print_item(io, "labels", [sortedpairs[i][1] for i in 1:length(sortedpairs)])
    print_item(io, "nobs", nobs(o))
end


#------------------------------------------------------------------# Cauchy
type FitCauchy{W<:Weight} <: DistributionStat{ScalarInput}
    value::Ds.Cauchy
    q::QuantileMM{W}
end
FitCauchy(wgt::Weight = LearningRate()) = FitCauchy(Ds.Cauchy(), QuantileMM(wgt))
fit!(o::FitCauchy, y::Real) = (fit!(o.q, y); o)
nobs(o::FitCauchy) = nobs(o.q)
function value(o::FitCauchy)
    o.value = Ds.Cauchy(o.q.value[2], 0.5 * (o.q.value[3] - o.q.value[1]))
end


#------------------------------------------------------------------------# Gamma
# method of moments, TODO: look at Distributions for MLE
type FitGamma{W<:Weight} <: DistributionStat{ScalarInput}
    value::Ds.Gamma
    var::Variance{W}
end
FitGamma(wgt::Weight = EqualWeight()) = FitGamma(Ds.Gamma(), Variance(wgt))
fit!(o::FitGamma, y::Real) = (fit!(o.var, y); o)
nobs(o::FitGamma) = nobs(o.var)
function value(o::FitGamma)
    m = mean(o.var)
    v = var(o.var)
    θ = v / m
    α = m / θ
    if nobs(o) > 1
        o.value = Ds.Gamma(α, θ)
    end
end


#-----------------------------------------------------------------------# LogNormal
type FitLogNormal{W<:Weight} <: DistributionStat{ScalarInput}
    value::Ds.LogNormal
    var::Variance{W}
end
FitLogNormal(wgt::Weight = EqualWeight()) = FitLogNormal(Ds.LogNormal(), Variance(wgt))
nobs(o::FitLogNormal) = nobs(o.var)
fit!(o::FitLogNormal, y::Real) = (fit!(o.var, log(y)); o)
function value(o::FitLogNormal)
    if nobs(o) > 1
        o.value = Ds.LogNormal(mean(o.var), std(o.var))
    end
end


#-----------------------------------------------------------------------# Normal
type FitNormal{W<:Weight} <: DistributionStat{ScalarInput}
    value::Ds.Normal
    var::Variance{W}
end
FitNormal(wgt::Weight = EqualWeight()) = FitNormal(Ds.Normal(), Variance(wgt))
nobs(o::FitNormal) = nobs(o.var)
fit!(o::FitNormal, y::Real) = (fit!(o.var, y); o)
function value(o::FitNormal)
    if nobs(o) > 1
        o.value = Ds.Normal(mean(o.var), std(o.var))
    end
end


#-----------------------------------------------------------------------# Multinomial
type FitMultinomial{W<:Weight} <: DistributionStat{VectorInput}
    value::Ds.Multinomial
    means::Means{W}
end
function FitMultinomial(p::Integer, wgt::Weight = EqualWeight)
    FitMultinomial(Ds.Multinomial(p, ones(p) / p), Means(p, wgt))
end
nobs(o::FitMultinomial) = nobs(o.means)
fit!{T<:Real}(o::FitMultinomial, y::AVec{T}) = (fit!(o.means, y); o)
function value(o::FitMultinomial)
    m = mean(o.means)
    o.value = Ds.Multinomial(round(Int, sum(m)), m / sum(m))
end



#---------------------------------------------------------------------# MvNormal
type FitMvNormal{W<:Weight} <: DistributionStat{VectorInput}
    value::Ds.MvNormal
    cov::CovMatrix{W}
end
function FitMvNormal(p::Integer, wgt::Weight = EqualWeight)
    FitMvNormal(Ds.MvNormal(zeros(p), eye(p)), CovMatrix(p, wgt))
end
nobs(o::FitMvNormal) = nobs(o.cov)
Base.std(d::FitMvNormal) = sqrt(var(d))  # No std() method from Distributions?
fit!{T<:Real}(o::FitMvNormal, y::AMat{T}) = (fit!(o.cov, y); o)
function value(o::FitMvNormal)
    c = cov(o.cov)
    if isposdef(c)
        o.value = Ds.MvNormal(mean(o.cov), c)
    else
        warn("Covariance not positive definite.  More data needed.")
    end
end



#---------------------------------------------------------------------# convenience constructors
for nm in [:FitBeta, :FitCauchy, :FitGamma, :FitLogNormal, :FitNormal]
    eval(parse("""
        function $nm{T<:Real}(y::AVec{T}, wgt::Weight = EqualWeight())
            o = $nm(wgt)
            fit!(o, y)
            o
        end
    """))
end

for nm in [:FitMultinomial, :FitMvNormal]
    eval(parse("""
        function $nm{T<:Real}(y::AMat{T}, wgt::Weight = EqualWeight())
            o = $nm(size(y, 2), wgt)
            fit!(o, y)
            o
        end
    """))
end

for nm in[:Beta, :Categorical, :Cauchy, :Gamma, :LogNormal, :Normal, :Multinomial, :MvNormal]
    eval(parse("""
        fitdistribution(::Type{Ds.$nm}, args...) = Fit$nm(args...)
    """))
end



#--------------------------------------------------------------# fitdistribution docs
"""
Estimate the parameters of a distribution.

```julia
using Distributions
# Univariate distributions
o = fitdistribution(Beta, y)
o = fitdistribution(Categorical, y)  # ignores Weight
o = fitdistribution(Cauchy, y)
o = fitdistribution(Gamma, y)
o = fitdistribution(LogNormal, y)
o = fitdistribution(Normal, y)
mean(o)
var(o)
std(o)
params(o)

# Multivariate distributions
o = fitdistribution(Multinomial, x)
o = fitdistribution(MvNormal, x)
mean(o)
var(o)
std(o)
cov(o)
```
"""
fitdistribution
