#=
	Descrição do modelo
		- Variáveis
		- Constraints
=#
		
model = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(), "OutputFlag" => 1, "TimeLimit" =>  LimiteTempo, "MIPGap" => LimiteGap, "Threads" => 4))


@variable(model,	x[1:subs, 1:jobs, 1:T],				binary = true)		# Var de decisão (1 quando a task está ativa)
@variable(model,	phi[1:subs, 1:jobs, 1:T],			binary = true)		# Var auxiliar (startups/subidas)
@variable(model,	alpha[1:subs, 1:jobs, 1:T],			binary = true)		# Var auxiliar (descidas)
@variable(model,	beta[1:subs,1:subs, 1:jobs, 1:T],	binary = true)		# Var auxiliar (redundancia)
@variable(model,	soc[1:subs, 1:T])										# SoC
@variable(model,	0 <= lambda[1:subs, 1:T] <= 1)							# Limita o uso da bateria
@variable(model,	b[1:subs, 1:T])											# Var auxiliar (1 quando a barteria está carregando)
@variable(model,	i[1:subs, 1:T])											# Corrente na bateria

#----------VAR AUXILIARES (SUBIDAS/DESCIDAS DE TASKS)----------
# Subidas: phi
for s in 1:subs
	for t in 1:T
		for j in 1:jobs
			if t == 1
				@constraint(model, phi[s, j, t] >= x[s,j,t] - 0)
			else
				@constraint(model, phi[s, j, t] >= x[s,j,t] - x[s,j,t - 1])
			end
		end
	end
end
for s in 1:subs
	for t in 1:T
		for j in 1:jobs
			if t == 1
				@constraint(model, phi[s, j, t] <= 2 - x[s,j,t] - 0)
			else
				@constraint(model, phi[s, j, t] <= 2 - x[s,j,t] - x[s,j,t - 1])
			end
		end
	end
end

# Descidas: alpha
for s in 1:subs
	for t in 2:T
		for j in 1:jobs
			@constraint(model, alpha[s,j,t] >= x[s,j,t-1] - x[s,j,t])
			@constraint(model, alpha[s,j,t] <= x[s,j,t-1])
			@constraint(model, alpha[s,j,t] <= x[s,j,t-1] - x[s,j,t] + phi[s, j, t])
		end
	end
end


#----------CONSTRAINTS DE TEMPO E STARTUPS----------
# Min/max numero de startups de uma job
for s in 1:subs
	for j in 1:jobs
		@constraint(model, sum(phi[s, j, t] for t in 1:T) >= min_statup[s][j])
		@constraint(model, sum(phi[s, j, t] for t in 1:T) <= max_statup[s][j])
	end
end

# Min/max numero de startups GLOBAIS de uma job
for j in 1:jobs
	@constraint(model, sum(phi[s, j, t] for s in 1:subs for t in 1:T) >= min_statup_g[j])
	@constraint(model, sum(phi[s, j, t] for s in 1:subs for t in 1:T) <= max_statup_g[j])
end

# Janela de execução
for s in 1:subs 
	for j in 1:jobs
		@constraint(model, sum(x[s, j, t] for t in 1:win_min[s][j]) == 0)
		@constraint(model, sum(x[s, j, t] for t in win_max[s][j] + 1:T) == 0)
	end
end

# Periodo MIN entre jobs
for s in 1:subs
	for j in 1:jobs
		for t in 1:T - min_periodo_job[s][j] + 1
			@constraint(model, sum(phi[s, j, t_] for t_ in t:t + min_periodo_job[s][j] - 1) <= 1)
		end
	end
end 

# Periodo MAX entre jobs
for s in 1:subs
	for j in 1:jobs
		for t in 1:T - max_periodo_job[s][j] + 1
			@constraint(model, sum(phi[s, j, t_] for t_ in t:t + max_periodo_job[s][j] - 1) >= 1)
		end
	end
end 

# Duração MIN das jobs
for s in 1:subs
	for j in 1:jobs
		for t in 1:T -  min_cpu_time[s][j] + 1
			@constraint(model, sum(x[s, j, t_] for t_ in t:t +  min_cpu_time[s][j] - 1) >= min_cpu_time[s][j] * phi[s, j, t])
		end
	end
end

for s in 1:subs
	for j in 1:jobs
	# Duração MAX das jobs
		for t in 1:T -  max_cpu_time[s][j]
			@constraint(model, sum(x[s, j, t_] for t_ in t:t +  max_cpu_time[s][j]) <=  max_cpu_time[s][j])
		end
	# Duração MIN no final do periodo
		for t in T - min_cpu_time[s][j] + 2:T
			@constraint(model, sum(x[s, j, t_] for t_ in t:T) >= (T - t + 1) * phi[s, j, t])
		end    
	end    
end


#----------CONSTRAINTS DE BATERIA----------
# Battery constraints
for s in 1:subs
	for t in 1:T
		@constraint(model, b[s,t] / v_bat == i[s,t])  # P = V * I 
		@constraint(model, b[s,t] == recurso_p[s][t] - sum(uso_p[s][j] * x[s,j,t] for j in 1:jobs)) # Pin(t) - Putilizado(t) = Pcarga da bateria(t)
		if t == 1
			@constraint(model, soc[s,t] ==  soc_inicial + (ef / q) * (i[s,t] / 60) ) # SoC(1) = SoC(0) + p_carga[1]/60
		else
			@constraint(model, soc[s,t] ==  soc[s,t - 1] + (ef / q) * (i[s,t] / 60)) # SoC(t) = SoC(t-1) + (ef / Q) * I(t)
		end
		@constraint(model, rho <= (soc[s,t] ) <= 1)
	end
end

# Restrição de SoC
if restringe 
	for s in 1:subs
		@constraint(model, (soc_inicial - soc_inicial * d) <= soc[s,T] <= (soc_inicial + soc_inicial * d) )
	end
end

# Recurso utilizado deve ser menor que o recurso disponível
for s in 1:subs
	for t in 1:T
		@constraint(model, sum(uso_p[s][j] * x[s,j,t] for j in 1:jobs) <= recurso_p[s][t]  + bat_usage * v_bat * (1 - lambda[s,t]))
	end
end


#----------CONSTRAINTS DE CONSTELAÇAO----------
# Redundância
for s in 1:subs
	for sl in 1:subs
		if s != sl
			for j in 1:jobs
				for t in 1:T
					@constraint(model, phi[s,j,t] + phi[sl,j,t] <= 2 + M*(1-beta[s,sl,j,t]))
					@constraint(model, phi[s,j,t] + phi[sl,j,t] >= -M*(1-beta[s,sl,j,t]) + 2)
					#@constraint(model, -M*(1-beta[s,sl,j,t]) + 2 <= phi[s,j,t] + phi[sl,j,t] <= 2 + M*(1-beta[s,sl,j,t]))
				end
			end
		end
	end
end

# Inicialização sincronizada
for j in 1:jobs
	if sincronous[j] ==1
		for s in 1:subs
			for t in 1:T
				@constraint(model, sum(phi[s, j, t] for s in 1:subs) >= subs * phi[s,j,t])
			end
		end
	end
end 

# Desligamento sincronizado
for j in 1:jobs
	if sincronous[j] ==1
		for s in 1:subs
			for t in 1:T
				@constraint(model, sum(alpha[s, j, t] for s in 1:subs) >= subs * alpha[s,j,t])
			end
		end
	end
end 


#----------CONTABILIZAÇÃO DE A E B (Mavrotas)----------
global A = 0
global B = 0 
for s in 1:subs
	for j in 1:jobs
		if constelação[j] == 1
			global A = A + sum(priority[s][j][t] * x[s,j,t] for t in 1:T)
		else 
			global B = B + sum(priority[s][j][t] * x[s,j,t] for t in 1:T)
		end
	end
end

#----------CONTABILIZAÇÃO DE REDUNDANCIA (Mavrotas)----------
global beta_acumulado = 0
for s in 1:subs
	for sl in 1:subs
		if s != sl
			for j in 1:jobs
					global beta_acumulado = beta_acumulado + sum(beta[s,sl,j,t] for t in 1:T)
			end
		end
	end
end