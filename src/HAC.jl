function k_tr{T}(x::T)
    if(isnan(x) || abs(x)<= one(1))
        return one(Float64)
    else
        return zero(Float64)
    end
end

function k_bt{T}(x::T)
    if isnan(x)
        one(Float64)
    end
    float(max(one(1)-abs(x), zero(1)))
end

function k_pr{T}(x::T)
    if isnan(x)
        one(Float64)
    end
    ax = abs(x)
    if(ax > one(T))
        zero(Float64)
    elseif ax <= .5
        float(1 - 6 * x^2 + 6 * ax^3)
    else
        float(2 * (1-ax)^3)
    end
end

function k_qs{T <: Number}(x::T)
    if isnan(x)
        one(Float64)
    end
    if(isequal(x, zero(eltype(x))))
        one(Float64)
    else
        return (25/(12*π²*x^2))*(sin(sixπ*x/5)/(sixπ*x/5)-cos(sixπ*x/5))
    end
end

function k_th{T <: Number}(x::T)
    if isnan(x)
        one(Float64)
    end
    ax = abs(x)
    if(ax < one(T))
        (1 + cos(π*x))/2
    else
        zero(Float64)
    end
end

##############################################################################
##
## Optimal band-width
##
##############################################################################

abstract BandwidthType{G}
abstract OptimalBandwidth

immutable NeweyWest <: OptimalBandwidth end
immutable Andrews <: OptimalBandwidth end


immutable Fixed   <: BandwidthType end
immutable Optimal{G<:OptimalBandwidth} <: BandwidthType{G} end

type TruncatedKernel{G<:BandwidthType, F<:Function} <: HAC{G}
  kernel::F
  bwtype::G
  bw::Array{Float64, 1}
  weights::Array{Float64,1}
end

type BartlettKernel{G<:BandwidthType, F<:Function} <: HAC{G}
  kernel::F
  bwtype::G
  bw::Array{Float64, 1}
  weights::Array{Float64,1}
end

type ParzenKernel{G<:BandwidthType, F<:Function} <: HAC{G}
  kernel::F
  bwtype::G
  bw::Array{Float64, 1}
  weights::Array{Float64,1}
end

type TukeyHanningKernel{G<:BandwidthType, F<:Function} <: HAC{G}
  kernel::F
  bwtype::G
  bw::Array{Float64, 1}
  weights::Array{Float64,1}
end

type QuadraticSpectralKernel{G<:BandwidthType, F<:Function} <: HAC{G}
  kernel::F
  bwtype::G
  bw::Array{Float64, 1}
  weights::Array{Float64,1}
end

type VARHAC <: HAC
    imax::Int64
    ilag::Int64
    imodel::Int64
end

typealias TRK TruncatedKernel
typealias BTK BartlettKernel
typealias PRK ParzenKernel
typealias THK TukeyHanningKernel
typealias QSK QuadraticSpectralKernel

Optimal() = Optimal{Andrews}()

TruncatedKernel()                   = TRK(k_tr, Optimal(), Array{Float64}(1), Array{Float64}(0))
BartlettKernel()                    = BTK(k_bt, Optimal(), Array{Float64}(1), Array{Float64}(0))
ParzenKernel()                      = PRK(k_pr, Optimal(), Array{Float64}(1), Array{Float64}(0))
TukeyHanningKernel()                = THK(k_th, Optimal(), Array{Float64}(1), Array{Float64}(0))
QuadraticSpectralKernel()           = QSK(k_qs, Optimal(), Array{Float64}(1), Array{Float64}(0))

BartlettKernel(x::Type{NeweyWest})          = BTK(k_bt, Optimal{NeweyWest}(), Array{Float64}(1), Array{Float64}(0))
ParzenKernel(x::Type{NeweyWest})            = PRK(k_pr, Optimal{NeweyWest}(), Array{Float64}(1), Array{Float64}(0))
TukeyHanningKernel(x::Type{NeweyWest})      = THK(k_th, Optimal{NeweyWest}(), Array{Float64}(1), Array{Float64}(0))
QuadraticSpectralKernel(x::Type{NeweyWest}) = QSK(k_qs, Optimal{NeweyWest}(), Array{Float64}(1), Array{Float64}(0))

BartlettKernel(x::Type{Andrews})          = BTK(k_bt, Optimal{Andrews}(), Array{Float64}(1), Array{Float64}(0))
ParzenKernel(x::Type{Andrews})            = PRK(k_pr, Optimal{Andrews}(), Array{Float64}(1), Array{Float64}(0))
TukeyHanningKernel(x::Type{Andrews})      = THK(k_th, Optimal{Andrews}(), Array{Float64}(1), Array{Float64}(0))
QuadraticSpectralKernel(x::Type{Andrews}) = QSK(k_qs, Optimal{Andrews}(), Array{Float64}(1), Array{Float64}(0))

TruncatedKernel(bw::Number)         = TRK(k_tr, Fixed(), [float(bw)], Array{Float64}(0))
BartlettKernel(bw::Number)          = BTK(k_bt, Fixed(), [float(bw)], Array{Float64}(0))
ParzenKernel(bw::Number)            = PRK(k_pr, Fixed(), [float(bw)], Array{Float64}(0))
TukeyHanningKernel(bw::Number)      = THK(k_th, Fixed(), [float(bw)], Array{Float64}(0))
QuadraticSpectralKernel(bw::Number) = QSK(k_qs, Fixed(), [float(bw)], Array{Float64}(0))

VARHAC()                            = VARHAC(2, 2, 1)
VARHAC(imax::Int64)                 = VARHAC(imax, 2, 1)


bandwidth{G<:Fixed}(k::HAC{G}, X::AbstractMatrix) = k.bw
bandwidth{G<:Andrews}(k::HAC{Optimal{G}}, X::AbstractMatrix) = bwAndrews(k, )

function bandwidth(k::QuadraticSpectralKernel, X::AbstractMatrix)
    return k.bw(X, k)
end

kernel(k::HAC, x::Real) = k.kernel(x)

function Γ(X::AbstractMatrix, j::Int64)
    T, p = size(X)
    Q = zeros(eltype(X), p, p)
    if j>=0
        for h=1:p, s = 1:h
            for t = j+1:T
                @inbounds Q[s, h] = Q[s, h] + X[t, s]*X[t-j, h]
            end
        end
    else
        for h=1:p, s = 1:h
            for t = -j+1:T
                @inbounds Q[s,h] = Q[s ,h] + X[t+j, s]*X[t,h]
            end
        end
    end
    return Q
end

vcov(X::AbstractMatrix, k::VARHAC) = varhac(X, k.imax, k.ilag, k.imodel)


function vcov(X::AbstractMatrix, k::HAC, bw, D, prewhite::Bool)
  n, p = size(X)
  Q  = zeros(p, p)
  for j in -floor(Int, bw):floor(Int, bw)
      Base.BLAS.axpy!(kernel(k, j/bw), Γ(X, j), Q)
  end
  Base.LinAlg.copytri!(Q, 'U')
  if prewhite
      Q[:] = D*Q*D'
      n += 1
  end
  return scale!(Q, 1/n)
end

function vcov(X::AbstractMatrix, k::QuadraticSpectralKernel, bw, D, prewhite::Bool)
  n, p = size(X)
  Q  = zeros(p, p)
  for j in -n:n
      Base.BLAS.axpy!(kernel(k, j/bw), Γ(X, j), Q)
  end
  Base.LinAlg.copytri!(Q, 'U')
  if prewhite
      Q[:] = D*Q*D'
      n += 1
  end
  return scale!(Q, 1/n)
end

function vcov(X::AbstractMatrix, k::HAC{Fixed}; prewhite=true)
    D = I
    !prewhite || ((X, D) = pre_white(X))
    bw = k.bw[1]
    vcov(X, k, bw, D, prewhite)
end

function vcov(X::AbstractMatrix, k::HAC{Optimal{Andrews}}; prewhite=true)
    p = size(X, 2)
    D = I
    !prewhite || ((X, D) = pre_white(X))
    isempty(k.weights) && (k.weights = ones(p))
    bw = bwAndrews(X, k, prewhite)
    vcov(X, k, bw, D, prewhite)
end

function vcov(X::AbstractMatrix, k::HAC{Optimal{NeweyWest}}; prewhite=true)
    p = size(X, 2)
    D = I
    !prewhite || ((X, D) = pre_white(X))
    isempty(k.weights) && (k.weights = ones(p))
    bw = bwNeweyWest(X, k, prewhite)
    vcov(X, k, bw, D, prewhite)
end


function vcov(r::DataFrameRegressionModel, k::HAC; args...)
  p = size(r.model.pp.X, 2)
  k.weights = ones(p)
  "(Intercept)" ∈ coefnames(r.mf) && (k.weights[find("(Intercept)" .== coefnames(r.mf))] = 0)
  vcov(r.model, k; args...)
end

vcov(r::DataFrameRegressionModel, k::VARHAC) = vcov(r.model, k)

function vcov(l::LinPredModel, k::VARHAC)
  B = meat(l, k)
  A = bread(l)
  scale!(A*B*A, 1/nobs(l))
end


function vcov(l::LinPredModel, k::HAC; args...)
  B = meat(l, k; args...)
  A = bread(l)
  scale!(A*B*A, 1/nobs(l))
end

function meat(l::LinPredModel, k::HAC; args...)
  u = wrkresidwts(l.rr)
  X = ModelMatrix(l)
  z = X.*u
  vcov(z, k; args...)
end

function meat(l::LinPredModel, k::VARHAC)
  u = wrkresidwts(l.rr)
  X = ModelMatrix(l)
  z = X.*u
  vcov(z, k)
end
