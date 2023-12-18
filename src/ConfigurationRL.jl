module ConfigurationRL

using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite
using ExportAll
using IntervalSets
using ReinforcementLearning
using Revise
using JuMP


include("NetworkFunctions.jl")
include("Configurations.jl")
using .NetworkFunctions
using .Configurations


mutable struct PowerEnv <: AbstractEnv
    action_space::Vector{Int}
    state_space::Space{Vector{ClosedInterval{Float64}}}
    action::Int
    state::Vector{Float64}
    reward::Float64
    n_actions::Int
    power_network::Dict{String, Any}
    power_network_path::String
    bus_number::Int
    is_done::Bool
    n_original_buses::Int
    state_size::Int
    bus_connected_config
    time::Int
    prev_cost::Float64
end

mutable struct MultiPowerEnv <: AbstractEnv
    action_space::Vector{Int}
    state_space::Space{Vector{ClosedInterval{Float64}}}
    action::Int
    state::Vector{Float64}
    reward::Float64
    n_actions::Int
    power_network::Dict{String, Any}
    power_network_path::String
    bus_number::Int
    is_done::Bool
    n_original_buses::Int
    state_size::Int
    bus_connected_config
    time::Int
    prev_cost::Float64
end


function RLBase.action_space(env::PowerEnv)
    return env.action_space
end

function RLBase.action_space(env::MultiPowerEnv)
    return env.action_space
end


function RLBase.state(env::PowerEnv)
    return env.state
end

function RLBase.state(env::MultiPowerEnv)
    return env.state
end


function RLBase.state_space(env::PowerEnv)
    return env.state_space
end

function RLBase.state_space(env::MultiPowerEnv)
    return env.state_space
end

function RLBase.reward(env::PowerEnv)
    return env.reward
end

function RLBase.reward(env::MultiPowerEnv)
    return env.reward
end

function RLBase.is_terminated(env::PowerEnv)
    return env.is_done
end

function RLBase.is_terminated(env::MultiPowerEnv)
    return env.is_done
end


function RLBase.reset!(env::PowerEnv)

    # Parse and solve original OPF problem instance.
    config_template = make_configuration_template(env.power_network, env.bus_number)
    network_data = apply_bus_configuration(env.power_network, config_template)
    
    result = solve_opf(network_data, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0))

    # Set environment's power network field to power network along with solved powerflow data.
    power_network = copy(network_data)
    update_data!(power_network, result["solution"])
    env.power_network = power_network

    # Map state to state represemted by current powerflow solution.
    env.state = network_to_state(env.power_network, env.bus_number, env.n_original_buses, env.bus_connected_config);

    # Reset is_done.
    env.is_done = false
    env.time = 0

    # Reset current action (set to the "do nothing" action).
    env.action = 0

    # Set reward to negative cost of original OPF cost.
    env.reward = 0
    env.prev_cost = result["objective"]
    # env.reward = 0

    nothing

end

function RLBase.reset!(env::MultiPowerEnv)

    # Parse and solve original OPF problem instance.
    config_template = make_configuration_template(env.power_network, env.bus_number)
    network_data = apply_bus_configuration(env.power_network, config_template)
    
    result = solve_opf(network_data, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0))

    # Set environment's power network field to power network along with solved powerflow data.
    power_network = copy(network_data)
    update_data!(power_network, result["solution"])
    env.power_network = power_network

    # Map state to state represemted by current powerflow solution.
    env.state = network_to_state(env.power_network, env.bus_number, env.n_original_buses, env.bus_connected_config);

    # Reset is_done.
    env.is_done = false
    env.time = 0

    # Reset current action (set to the "do nothing" action).
    env.action = 0

    # Set reward to negative cost of original OPF cost.
    env.reward = 0
    env.prev_cost = result["objective"]
    # env.reward = 0

    nothing

end


function (env::PowerEnv)(action)
    
    env.time += 1

    # If reward doesn't improve (no improvement in optimization solution), finish.
    # if previous_reward >= env.reward
    if (env.action == action) || (env.time >= 5)
    # if env.time >= 2
        env.is_done = true
    end

    # Store action.
    env.action = action

    # println(action)

    # Generate configuration based on action.
    config_template = make_configuration_template(env.power_network, env.bus_number)
    config = binary_to_configuration(config_template, action)

    # Store previous reward before updating.
    previous_cost = copy(env.prev_cost)

    # Obtain reward by resolving with configuration determined by action. 
    solution_cost, configured_solution = configuration_cost(env.power_network, config)
    env.reward = previous_cost - solution_cost
    env.prev_cost = solution_cost

    # Map OPF network solution to environment state.
    env.state = network_to_state(configured_solution, env.bus_number, env.n_original_buses, env.bus_connected_config)
    # println(env.state)
    nothing

end

function (env::MultiPowerEnv)(action)
    
    env.time += 1

    # If reward doesn't improve (no improvement in optimization solution), finish.
    # if previous_reward >= env.reward
    if (env.action == action) || (env.time >= 5)
    # if env.time >= 2
        env.is_done = true
    end

    # Store action.
    env.action = action

    # println(action)

    # Generate configuration based on action.
    config_template = make_configuration_template(env.power_network, env.bus_number)
    config = binary_to_configuration(config_template, action)

    # Store previous reward before updating.
    previous_cost = copy(env.prev_cost)

    # Obtain reward by resolving with configuration determined by action. 
    solution_cost, configured_solution = configuration_cost(env.power_network, config)
    env.reward = previous_cost - solution_cost 
    env.prev_cost = solution_cost

    # Map OPF network solution to environment state.
    env.state = network_to_state(configured_solution, env.bus_number, env.n_original_buses, env.bus_connected_config)
    println(env.state)
    nothing

end


function network_to_state(network, bus, n_buses, connected_bus_network)

    # Generate power network with fully connected config.
    # fully_connected_config = make_configuration_template(env.power_network, env.bus_number; connected=1)
    # network_data = apply_bus_configuration(PowerModels.parse_file(env.power_network_path), fully_connected_config)    

    # Get adjacent branches, loads, generators.
    adj_branches = merge(get_adjacent_branches(network, bus), get_adjacent_branches(network, bus + n_buses))
    adj_loads = merge(get_adjacent_loads(network, bus), get_adjacent_loads(network, bus + n_buses))
    adj_gens = merge(get_adjacent_generators(network, bus), get_adjacent_generators(network, bus + n_buses))
    
    # Get adjacent branches, loads, generators of connected config.
    connected_adj_branches = merge(get_adjacent_branches(connected_bus_network, bus), get_adjacent_branches(connected_bus_network, bus + n_buses))
    connected_adj_loads = merge(get_adjacent_loads(connected_bus_network, bus), get_adjacent_loads(connected_bus_network, bus + n_buses))
    connected_adj_gens = merge(get_adjacent_generators(connected_bus_network, bus), get_adjacent_generators(connected_bus_network, bus + n_buses))

    # Get sorted keys of all adjacent items.
    sorted_branch_keys = sort(parse.(Int, collect(keys(connected_adj_branches))))
    sorted_load_keys = sort(parse.(Int, collect(keys(connected_adj_loads))))
    sorted_gen_keys = sort(parse.(Int, collect(keys(connected_adj_gens))))

    # Create branch state.
    branch_state = []
    for branch_key in sorted_branch_keys
        
        # Append values to branch_state vector.
        if string(branch_key) in keys(adj_branches)
            
            # Need to change source_id to a number, from list.
            branch_dict = copy(network["branch"][string(branch_key)])
            branch_dict["source_id"] = branch_dict["source_id"][2]

            append!(branch_state, values(branch_dict))

        else
            # Need to change source_id to a number, from list.
            branch_dict = copy(connected_bus_network["branch"][string(branch_key)])
            branch_dict["source_id"] = branch_dict["source_id"][2]
            
            append!(branch_state, zeros(1, length(values(branch_dict))))
        end
        
    end
    
    # Create load state.
    load_state = []
    for load_key in sorted_load_keys
        
        if string(load_key) in keys(adj_loads)

            # Need to change source_id to a number, from list.
            load_dict = copy(network["load"][string(load_key)])
            load_dict["source_id"] = load_dict["source_id"][2]

            # Append values to load_state vector.
            append!(load_state, values(load_dict))

        else
            # Need to change source_id to a number, from list.
            load_dict = copy(connected_bus_network["load"][string(load_key)])
            load_dict["source_id"] = load_dict["source_id"][2]

            # Append values to load_state vector.
            append!(load_state, zeros(1, length(values(load_dict))))

        end
    end

    # Create gen state.
    gen_state = []
    for gen_key in sorted_gen_keys
        
        if string(gen_key) in keys(adj_gens)

            # Need to change source_id to a number, from list.
            gen_dict = copy(network["gen"][gen_key])
            gen_dict["source_id"] = gen_dict["source_id"][2]
            gen_dict["cost_1"] = gen_dict["cost"][1]
            gen_dict["cost_2"] = gen_dict["cost"][2]
            delete!(gen_dict, "cost")

            # Append values to gen_state vector.
            append!(gen_state, values(gen_dict))

        else

            # Need to change source_id to a number, from list.
            gen_dict = copy(connected_bus_network["gen"][gen_key])
            gen_dict["source_id"] = gen_dict["source_id"][2]
            gen_dict["cost_1"] = gen_dict["cost"][1]
            gen_dict["cost_2"] = gen_dict["cost"][2]
            delete!(gen_dict, "cost")

            # Append values to gen_state vector.
            append!(gen_state,  zeros(1, length(values(gen_dict))))

        end
        
    end

    return vcat(branch_state, load_state, gen_state)

end

function network_to_state(network, n_buses, connected_bus_network)

    # Generate power network with fully connected config.
    # fully_connected_config = make_configuration_template(env.power_network, env.bus_number; connected=1)
    # network_data = apply_bus_configuration(PowerModels.parse_file(env.power_network_path), fully_connected_config)    

    # Get adjacent branches, loads, generators.
    adj_branches = merge(get_adjacent_branches(network, bus), get_adjacent_branches(network, bus + n_buses))
    adj_loads = merge(get_adjacent_loads(network, bus), get_adjacent_loads(network, bus + n_buses))
    adj_gens = merge(get_adjacent_generators(network, bus), get_adjacent_generators(network, bus + n_buses))
    
    # Get adjacent branches, loads, generators of connected config.
    connected_adj_branches = merge(get_adjacent_branches(connected_bus_network, bus), get_adjacent_branches(connected_bus_network, bus + n_buses))
    connected_adj_loads = merge(get_adjacent_loads(connected_bus_network, bus), get_adjacent_loads(connected_bus_network, bus + n_buses))
    connected_adj_gens = merge(get_adjacent_generators(connected_bus_network, bus), get_adjacent_generators(connected_bus_network, bus + n_buses))

    # Get sorted keys of all adjacent items.
    sorted_branch_keys = sort(parse.(Int, collect(keys(connected_adj_branches))))
    sorted_load_keys = sort(parse.(Int, collect(keys(connected_adj_loads))))
    sorted_gen_keys = sort(parse.(Int, collect(keys(connected_adj_gens))))

    # Create branch state.
    branch_state = []
    for branch_key in sorted_branch_keys
        
        # Append values to branch_state vector.
        if branch_key in keys(adj_branches)
            
            # Need to change source_id to a number, from list.
            branch_dict = copy(network["branch"][string(branch_key)])
            branch_dict["source_id"] = branch_dict["source_id"][2]

            append!(branch_state, values(branch_dict))

        else
            # Need to change source_id to a number, from list.
            branch_dict = copy(connected_bus_network["branch"][string(branch_key)])
            branch_dict["source_id"] = branch_dict["source_id"][2]
            
            append!(branch_state, zeros(1, length(values(branch_dict))))
        end
        
    end
    
    # Create load state.
    load_state = []
    for load_key in sorted_load_keys
        
        if load_key in keys(adj_loads)

            # Need to change source_id to a number, from list.
            load_dict = copy(network["load"][string(load_key)])
            load_dict["source_id"] = load_dict["source_id"][2]

            # Append values to load_state vector.
            append!(load_state, values(load_dict))

        else
            # Need to change source_id to a number, from list.
            load_dict = copy(connected_bus_network["load"][string(load_key)])
            load_dict["source_id"] = load_dict["source_id"][2]

            # Append values to load_state vector.
            append!(load_state, zeros(1, length(values(load_dict))))

        end
    end

    # Create gen state.
    gen_state = []
    for gen_key in sorted_gen_keys
        
        if gen_key in keys(adj_gens)

            # Need to change source_id to a number, from list.
            gen_dict = copy(network["gen"][gen_key])
            gen_dict["source_id"] = gen_dict["source_id"][2]
            gen_dict["cost_1"] = gen_dict["cost"][1]
            gen_dict["cost_2"] = gen_dict["cost"][2]
            delete!(gen_dict, "cost")

            # Append values to gen_state vector.
            append!(gen_state, values(gen_dict))

        else

            # Need to change source_id to a number, from list.
            gen_dict = copy(connected_bus_network["gen"][gen_key])
            gen_dict["source_id"] = gen_dict["source_id"][2]
            gen_dict["cost_1"] = gen_dict["cost"][1]
            gen_dict["cost_2"] = gen_dict["cost"][2]
            delete!(gen_dict, "cost")

            # Append values to gen_state vector.
            append!(gen_state,  zeros(1, length(values(gen_dict))))

        end
        
    end

    return vcat(branch_state, load_state, gen_state)

end

@exportAll

end


