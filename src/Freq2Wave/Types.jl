@doc """
`CoB` is an abstract **c**hange **o**f **b**asis super-type 
"""->
abstract CoB


# ------------------------------------------------------------
# "N"FFT plan for equidistant points 

type FFTPlan{D}
	forwardFFT::Base.DFT.FFTW.cFFTWPlan
	backwardFFT::Base.DFT.FFTW.cFFTWPlan
	pre_phaseshift::Array{Complex{Float64}}
	post_phaseshift::Array{Complex{Float64}}
	x::Vector
	eps::Float64
	M::Int64
	N::Int64
	q::Int64
	tmpVec::Array{Complex{Float64},D}
end

function FFTPlan(samples::Vector, J::Integer, N::Integer)
	M = length(samples)
	myeps = samples[2] - samples[1]
	dilation = 2^J

	pre = Array{Complex{Float64}}(N)
	for l in 1:N
		pre[l] = cis( pi*(l-1)*myeps*M/dilation )
	end

	xi = samples / dilation
	post = cis( pi*N*xi )

	q = div(M, Int(dilation/myeps)) + 1
	tmpVec = Array{Complex{Float64}}( q*Int(dilation/myeps) )

	fP = plan_fft!(tmpVec)
	bP = plan_bfft!(tmpVec)

	FFTPlan(fP, bP, pre, post, xi, myeps, M, N, q, tmpVec)
end


# ------------------------------------------------------------
# Frequency to wavelets

@doc """
`Freq2Wave` is a change of basis type between frequency samples and wavelets. 

There are sub types for wavelets with and without boundary correction.
To initialize a `Freq2Wave` type, run

	Freq2Wave(samples, wavename::String, J::Int, B; ...)

- `samples` are the sampling locations as a vector for 1D and a matrix with 2 columns for 2D.
- `wave` is the name of the wavelet; see documentation for possibilities.
- `J` is the scale of the wavelet transform to reconstruct.
- `B` is the bandwidth of the samples; only needed if `samples` are non-uniform.
- Optional arguments (if needed) are passed to the functions computing Fourier transforms.
"""->
abstract Freq2Wave <: CoB

abstract Freq2Wave1D <: Freq2Wave
abstract Freq2Wave2D <: Freq2Wave
# The 2D Freq2BoundaryWave's need entries the 1D's do not, so don't
# use the dimension as a TypePar.

# No boundary correction
immutable Freq2NoBoundaryWave1D{P} <: Freq2Wave1D
	# Sampling
	internal::Vector{Complex{Float64}}
	weights::Nullable{ Vector{Complex{Float64}} }

	# Reconstruction
	J::Int64
	wavename::AbstractString

	# Multiplication
	#= NFFT::NFFT.NFFTPlan{1,0,Float64} =#
	NFFT::P

	tmpMulVec::Vector{Complex{Float64}}
end

immutable Freq2NoBoundaryWave2D <: Freq2Wave2D
	internal::Dict{ Symbol, Vector{Complex{Float64}} }
	weights::Nullable{ Vector{Complex{Float64}} }

	J::Int64
	wavename::AbstractString

	NFFT::NFFT.NFFTPlan{2,0,Float64}
	#= NFFT::FTPlan =#

	tmpMulVec::Vector{Complex{Float64}}
end

# Boundary correction
immutable Freq2BoundaryWave1D{P} <: Freq2Wave1D
	internal::Vector{Complex{Float64}}
	weights::Nullable{Vector{Complex{Float64}}}

	J::Int64
	wavename::AbstractString

	#= NFFT::NFFT.NFFTPlan{1,0,Float64} =#
	NFFT::P

	left::Matrix{Complex{Float64}}
	right::Matrix{Complex{Float64}}

	tmpMulVec::Vector{Complex{Float64}}
end

immutable Freq2BoundaryWave2D <: Freq2Wave2D
	internal::Dict{ Symbol, Vector{Complex{Float64}} }
	weights::Nullable{ Vector{Complex{Float64}} }

	J::Int64
	wavename::AbstractString

	NFFT::NFFT.NFFTPlan{2,0,Float64}
	NFFTx::NFFT.NFFTPlan{2,1,Float64}
	NFFTy::NFFT.NFFTPlan{2,2,Float64}

	left::Dict{ Symbol, Matrix{Complex{Float64}} }
	right::Dict{ Symbol, Matrix{Complex{Float64}} }

	tmpMulVec::Matrix{Complex{Float64}}
	tmpMulVecT::Matrix{Complex{Float64}} # Serves as the transpose of tmpMulVec
	tmpMulcVec::Vector{Complex{Float64}}
	weigthedVec::Vector{Complex{Float64}}
end


# ------------------------------------------------------------------------
# Constructors

function Freq2NoBoundaryWave1D(internal, weights, J, wavename, NFFT)
	tmpMulVec = Array{Complex{Float64}}( NFFT.M )
	Freq2NoBoundaryWave1D( internal, weights, J, wavename, NFFT, tmpMulVec )
end

function Freq2NoBoundaryWave2D(internal, weights, J, wavename, NFFT)
	tmpMulVec = Array{Complex{Float64}}( NFFT.M )
	Freq2NoBoundaryWave2D( internal, weights, J, wavename, NFFT, tmpMulVec )
end

function Freq2BoundaryWave1D(internal, weights, J, wavename, NFFT, left, right)
	tmpMulVec = Array{Complex{Float64}}( NFFT.M )
	Freq2BoundaryWave1D( internal, weights, J, wavename, NFFT, left, right, tmpMulVec )
end

function Freq2BoundaryWave2D(internal, weights, J, wavename, NFFT, left, right)
	tmpMulVec = similar(left[:x])
	tmpMulVecT = tmpMulVec.'

	tmpMulcVec = Array{Complex{Float64}}( NFFT.M )
	weigthedVec = similar(tmpMulcVec)

	vm = van_moment(wavename)
	NFFTx = NFFTPlan( NFFT.x[1,:], 1, (NFFT.N[1],vm) )
	NFFTy = NFFTPlan( NFFT.x[2,:], 2, (vm,NFFT.N[2]) )

	Freq2BoundaryWave2D( internal, weights, J, wavename, NFFT,
	NFFTx, NFFTy, left, right, tmpMulVec, tmpMulVecT, tmpMulcVec, weigthedVec )
end


# ------------------------------------------------------------------------
# Load methods

include("freq2wave.jl")

