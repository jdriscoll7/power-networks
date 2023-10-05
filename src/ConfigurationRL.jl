module ConfigurationRL

using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite
using ExportAll


include("NetworkFunctions.jl")
include("Configurations.jl")
using .NetworkFunctions
using .Configurations


mutable struct PowerEnv <: AbstractEnv
    action_space::Vector{Int}
    state_space::Vector{Float64}
    action::Int
    state::Vector{Float64}
    reward::Float64
    n_actions::Int
    power_network::Dict{String, Any}
    power_network_path::String
    bus_number::Int
    is_done::Bool
end


function action_space(env::PowerEnv)
    return env.action_space
end


function state(env::PowerEnv)
    return env.state
end


function state_space(env::PowerEnv)
    return env.state_space
end


function reward(env::PowerEnv)
    return env.reward
end


function is_terminated(env::PowerEnv)
    return env.is_done
end


function reset!(env::PowerEnv)

    # Parse and solve original OPF problem instance.
    network_data = PowerModels.parse_file(env.power_network_path)
    result = solve_opf(network_data, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0))

    # Set environment's power network field to power network along with solved powerflow data.
    env.power_network = result["solution"]

    # Map state to state represemted by current powerflow solution.
    env.state = network_to_state(env.power_network, env.bus_number);

    # Reset is_done.
    env.is_done = false

    # Reset current action (set to the "do nothing" action).
    env.action = 0

    # Set reward to negative cost of original OPF cost.
    env.reward = -result["cost"]

end
n_branches = get_adjacent_branches(env.power_network, env.bus_number)
    n_bits = 1 + 2*n_branches

    return 0..(2^n_bits)

function (env::PowerEnv)(action)
    
    # Store action.
    env.action = action

    # Generate configuration based on action.
    config_template = make_configuration_template(env.power_network, env.bus_number)
    config = binary_to_configuration(config_template, action)

    # Store previous reward before updating.
    previous_reward = copy(env.reward)

    # Obtain reward by resolving with configuration determined by action. 
    env.reward, env.power_network = configuration_cost(env.power_network, config)

    # If reward doesn't improve (no improvement in optimization solution), finish.
    if previous_reward == env.reward
        env.is_done = true
    end

    # Map OPF network solution to environment state.
    env.state = network_to_state(env.power_network, env.bus_number)

end


function network_to_state(network, bus)

    # Get adjacent branches, loads, generators.
    adj_branches = get_adjacent_branches(network, bus)
    adj_loads = get_adjacent_loads(network, bus)
    adj_gens = get_adjacent_generators(network, bus)

    # Get sorted keys of all adjacent items.
    sorted_branch_keys = sort(parse.(Int, collect(keys(adj_branches))))
    sorted_load_keys = sort(parse.(Int, collect(keys(adj_loads))))
    sorted_gen_keys = sort(parse.(Int, collect(keys(adj_gens))))

    # Create branch state.
    branch_state = []
    for branch_key in sorted_branch_keys
        
        # Need to change source_id to a number, from list.
        branch_dict = copy(network["branch"][branch_key])
        branch_dict["source_id"] = branch_dict["source_id"][2]

        # Append values to branch_state vector.
        append!(branch_state, values(branch_dict))
    end

    # Create load state.
    load_state = []
    for load_key in sorted_load_keys
        
        # Need to change source_id to a number, from list.
        load_dict = copy(network["load"][load_key])
        load_dict["source_id"] = load_dict["source_id"][2]

        # Append values to load_state vector.
        append!(load_state, values(load_dict))
    end

    # Create gen state.
    gen_state = []
    for gen_key in sorted_gen_keys
        
        # Need to change source_id to a number, from list.
        gen_dict = copy(network["gen"][gen_key])
        gen_dict["source_id"] = gen_dict["source_id"][2]
        gen_dict["cost_1"] = gen_dict["cost"][1]
        gen_dict["cost_2"] = gen_dict["cost"][2]
        delete!(gen_dict, "cost")

        # Append values to gen_state vector.
        append!(gen_state, values(gen_dict))
    end

    return vcat(branch_state, load_state, gen_state)

end


end


