using JuMP
using Gurobi 

	#include("examples/2_46_10.jl")
	#include("modelo.jl")

function mavrotas(simulID)
	include("examples/$(simulID).jl")

	#Lista de As
	global obj_A =[]

	#lista de Bs
	global obj_B=[]

	global gridpoints = 5
	global infeasible = false

	include("modelo.jl")
	#####################################################  A  ###########################################################
	#Acha Amax
	@objective(model, Max, A)
	try
		println("MAX A --------------------------------------------")
		@time begin
			JuMP.optimize!.(model);
		end

		global A_aqui = 0
		global B_aqui =0

		for s in 1:subs
			for j in 1:jobs
				if constelação[j] == 1
					global A_aqui = A_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
				else 
					global B_aqui = B_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
				end
			end
		end

		#Coloca o A encontrado na lista de As
		push!(obj_A, A_aqui)
		println("Amax = $(A_aqui) # # # # # # # # # #")
		infeasible = false
	catch
		println("Infeaseble [MAX A] --------------------------------------------")
		infeasible = true
	end




	include("modelo.jl") # Reinicia as variáveis do problema

	@variable(model, 0 <= slackvar) # Variável de "escape"

	@constraint(model, A == slackvar + obj_A[1] ) # Faz A ~= Amax

	# Encontra B max pra o valor já encontrado de A max
	@objective(model, Max, B - slackvar)
	if (!infeasible)
		try
			println("MAX A and B --------------------------------------------")
			@time begin
				JuMP.optimize!.(model);
			end
			println("Slack var: ", JuMP.value.(slackvar))

			global A_aqui = 0
			global B_aqui =0

			for s in 1:subs
				for j in 1:jobs
					if constelação[j] == 1 #Coloca os resultados de constelação em Aaqui
						global A_aqui = A_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
					else # e os resultados que não são de constelação em Baqui
						global B_aqui = B_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
					end
				end
			end

			#Coloca o B encontrado na lista de Bs
			push!(obj_B, B_aqui)
			println("B(min) for Amax = $(B_aqui) # # # # # # # # # #")
			infeasible = false
		catch
			println("Infeaseble [MAX A and B] --------------------------------------------")
			infeasible = true
		end
	end
	#Até aqui temos o ponto [Amax, B(para esse Amax)]




	#####################################################  B ###########################################################
	include("modelo.jl")

	#Encontra Bmax
	@objective(model, Max, B)

	if (!infeasible)
		try
			println("MAX B --------------------------------------------")
			@time begin
				JuMP.optimize!.(model);
			end

			global A_aqui = 0
			global B_aqui =0

			for s in 1:subs
				for j in 1:jobs
					if constelação[j] == 1 #Coloca os resultados de constelação em Aaqui
						global A_aqui = A_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
					else # e os resultados que não são de constelação em Baqui
						global B_aqui = B_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
					end
				end
			end

			#Coloca o B encontrado na lista de Bs
			push!(obj_B, B_aqui)
			println("Bmax = $(B_aqui) # # # # # # # # # #")
			infeasible = false
		catch
			println("Infeaseble [MAX B] --------------------------------------------")
			infeasible = true
		end
	end



	include("modelo.jl") #Reinicia as variáveis do problema

	@variable(model, 0 <= slackvar) # Variável de "escape"

	# Faz B ~= Bmax (força)
	@constraint(model, B == slackvar + obj_B[2])

	# Encontra A pra Bmax
	@objective(model, Max, A - slackvar)

	if (!infeasible)
		try
			println("MAX B and A --------------------------------------------")
			@time begin
				JuMP.optimize!.(model);
			end


			println("Slack: ", JuMP.value.(slackvar))

			global A_aqui = 0
			global B_aqui = 0

			for s in 1:subs
				for j in 1:jobs
					if constelação[j] == 1 #Coloca os resultados de constelação em Aaqui
						global A_aqui = A_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
					else # e os resultados que não são de constelação em Baqui
						global B_aqui = B_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
					end
				end
			end

			#Salva as variáveis
			#Bmax
			println("Writing to Bmax file.... --------------------------------------------")
			touch("codigo_dissertacao/simulations/$(simulID)_Bmax_EN.txt")
			open("codigo_dissertacao/simulations/$(simulID)_Bmax_EN.txt", "a") do io
				linha = string("Simulation ID: $(simulID)\nData format: sub,t,recurso_tot,recurso_A,recurso_B,solar,soc\n")
				write(io, linha)
				for s in 1:subs
					for t in 1:T
						linha = string(s ,",", t ,",", sum(JuMP.value.(x[s,j,t])*uso_p[s][j] for j in 1:jobs) ,",", sum(constelação[j]*JuMP.value.(x[s,j,t])*uso_p[s][j] for j in 1:jobs) ,",", sum((1-constelação[j])*JuMP.value.(x[s,j,t])*uso_p[s][j] for j in 1:jobs) ,",", recurso_p[s][t] ,",", JuMP.value.(soc[s,t]) ,"\n") 
						println(linha)
						write(io, linha)
					end
				end
			end

			touch("codigo_dissertacao/simulations/$(simulID)_Bmax_SCH.txt")
			open("codigo_dissertacao/simulations/$(simulID)_Bmax_SCH.txt", "a") do io
				linha = string("Simulation ID: $(simulID)\nData format: sub,job,x[1],..,x[T]\n")
				write(io, linha)
				for s in 1:subs
					for j in 1:jobs
						linha = string(s, ",", j, ",")
						write(io, linha)
						for t in 1:(T-1)
							linha = string(round(JuMP.value.(x[s,j,t])), ",")
							write(io, linha)	
						end
						linha = string(JuMP.value.(x[s,j,T]), "\n")
						write(io, linha)	
					end
				end
			end
			

			#Coloca o A encontrado na lista de As
			push!(obj_A, A_aqui)
			println("A(min) for Bmax = $(A_aqui) # # # # # # # # # #")
			infeasible = false
		catch
			println("Infeaseble [MAX B and A] --------------------------------------------")
			infeasible = true
		end
	end




	####################################################################
	# Loop pra achar os outros valores, fixando valores de A e achando B
	if (!infeasible)
		for grid in 1:gridpoints
			include("modelo.jl")

			@variable(model, 0 <= slackvar)

			#A[1] = Amax
			#A[2] = A para Bmax 
			valor = obj_A[2] + ((obj_A[1]-obj_A[2])/gridpoints)*grid

			#Fixa A
			@constraint(model, forca, A == slackvar + valor )

			#Acha Bmax pra o A fixado
			@objective(model, Max, B - slackvar)

			println("MAVROTAS --------------------------------------------")
			try
				@time begin
					JuMP.optimize!.(model);
				end
				println("Slack:", JuMP.value.(slackvar))

				global A_aqui = 0
				global B_aqui = 0

				for s in 1:subs
					for j in 1:jobs
						if constelação[j] == 1 #Coloca os resultados de constelação em Aaqui
							global A_aqui = A_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
						else # e os resultados que não são de constelação em Baqui
							global B_aqui = B_aqui + sum(priority[s][j][t] * JuMP.value.(x[s,j,t]) for t in 1:T)
						end
					end
				end
			
			#Coloca o A forçado encontrado na lista de As
			push!(obj_A, A_aqui)
			#Coloca o B encontrado na lista de Bs
			push!(obj_B, B_aqui)

			#Salva as variáveis
			#Amax
				if (grid == gridpoints)
					println("Writing to Amax file.... --------------------------------------------")
					touch("codigo_dissertacao/simulations/$(simulID)_Amax_EN.txt")
					open("codigo_dissertacao/simulations/$(simulID)_Amax_EN.txt", "a") do io
						linha = string("Simulation ID: $(simulID)\nData format: sub,t,recurso_tot,recurso_A,recurso_B,solar,soc\n")
						write(io, linha)
						for s in 1:subs
							for t in 1:T
								linha = string(s ,",", t ,",", sum(JuMP.value.(x[s,j,t])*uso_p[s][j] for j in 1:jobs) ,",", sum(constelação[j]*JuMP.value.(x[s,j,t])*uso_p[s][j] for j in 1:jobs) ,",", sum((1-constelação[j])*JuMP.value.(x[s,j,t])*uso_p[s][j] for j in 1:jobs) ,",", recurso_p[s][t] ,",", JuMP.value.(soc[s,t]) ,"\n") 
								write(io, linha)
							end
						end
					end

					touch("codigo_dissertacao/simulations/$(simulID)_Amax_SCH.txt")
					open("codigo_dissertacao/simulations/$(simulID)_Amax_SCH.txt", "a") do io
						linha = string("Simulation ID: $(simulID)\nData format: sub,job,x[1],..,x[T]\n")
						write(io, linha)
						for s in 1:subs
							for j in 1:jobs
								linha = string(s, ",", j, ",")
								write(io, linha)
								for t in 1:(T-1)
									linha = string(round(JuMP.value.(x[s,j,t])), ",")
									write(io, linha)	
								end
								linha = string(JuMP.value.(x[s,j,T]), "\n")
								write(io, linha)	
							end
						end
					end
				end
			catch
				println("Error at: Mavrotas No$(grid)/$(gridpoints)")
				infeasible = true
				return (!infeasible)
			end
		end

		#Remove o primeiro valor de A (Amax), pois ele é encontrado novamente no loop
		deleteat!(obj_A, 1)

		#Remove o último valor de B, pois já foi encontrado antes, é B(Amax)
		deleteat!(obj_B, length(obj_B))

		obj_B=sort(obj_B, rev=true)

		obj_B=round.(Int, obj_B)

		obj_A = sort(obj_A)
	else
		obj_A[1] = 0
		obj_B[1] = 0
	end

	#Escreve os dados do mavrotas (A, B)
	println("Writing to Mavrotas file.... --------------------------------------------")
	touch("codigo_dissertacao/simulations/$(simulID)_mavrotas.txt")
	open("codigo_dissertacao/simulations/$(simulID)_mavrotas.txt", "a") do io
		linha = string("Simulation ID: $(simulID)\nData format: A,B\n")
		write(io, linha)
		for i in 1:length(obj_A)
			linha = string(obj_A[i], ",", obj_B[i], "\n") 
			write(io, linha)
		end
	end
	
	println("All done")
	return (!infeasible)
end