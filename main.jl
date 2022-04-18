using JuMP
using Gurobi
include("mavrotas.jl")

continuar = mavrotas("2_46_10")

if (continuar)
	continuar = mavrotas("2_96_10_2")
end