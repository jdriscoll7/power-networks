module ComponentsRL

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

mutable struct NetworkManager
    network::Dict{String, Any}
    config::Dict{String, Any}
    network_sol::Dict{String, Any}
    config_sol::Dict{String, Any}
    busbar_connected::Dict{String, Bool}
end

mutable struct Component
    parameter_data::Vector{Float64}
    opt_data::Vector{Float64}
    id::Any
end

mutable struct ComponentConfiguration
    id::Any
    type::String
    config_value::Vector{Float64}
end

mutable struct BranchConfiguration
    id::String
    calling_bus::String
    bus_decision::Int
    on_decision::Int
end


function create_network_manager(network_data)

    n_buses = length(keys(network_data["bus"]))

    # Setup configurable network as copy of given data.
    config_network = deepcopy(network_data)

     # If busbar doesn't exist, create it.
     for bus_i in 1:n_buses
        new_bus_number = bus_i + n_buses
        new_bus_id = string(new_bus_number)
        if !haskey(network_data["bus"], new_bus_id)
            config_network["bus"][new_bus_id] = deepcopy(network_data["bus"][string(bus_i)])
            config_network["bus"][new_bus_id]["source_id"][2] = new_bus_number
            config_network["bus"][new_bus_id]["index"] = new_bus_number
            config_network["bus"][new_bus_id]["bus_i"] = new_bus_number
        end
    end

    # Solve for given network data.
    network_sol = solve_opf(network_data, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>200, "print_level"=>0), setting = Dict("output" => Dict("duals" => true)))["solution"]
    config_sol = solve_opf(network_data, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>200, "print_level"=>0), setting = Dict("output" => Dict("duals" => true)))["solution"]    

    # Initialize all bus-busbar connections to false.
    busbar_connections = Dict(k => false for k in keys(network_data["bus"]))

    # Return networkmanager object.
    return NetworkManager(deepcopy(network_data), config_network, network_sol, config_sol, busbar_connections)

end

# Returns value of reconfigured optimization solution, updates configured solution/network in manager.
function configure_and_resolve!(network_manager::NetworkManager, configuration::BranchConfiguration)

    # Save previous state of network_manager to restore if config is invalid - may be expensive.
    network_manager_save = network_manager

    id = configuration.id
    int_id = parse(Int, id)

    int_calling_bus = parse(Int, configuration.calling_bus)
    # int_calling_bus = configuration.calling_bus

    n_branches = length(keys(network_manager.network["branch"]))
    n_buses = length(keys(network_manager.network["bus"]))

    bus_number = int_calling_bus
    new_bus_number = int_calling_bus + n_buses
    new_bus_id = string(new_bus_number)

    # If busbar doesn't exist, create it.
    if !haskey(network_manager.network["bus"], new_bus_id)
        network_manager.config["bus"][new_bus_id] = deepcopy(network_manager.network["bus"][configuration.calling_bus])
        network_manager.config["bus"][new_bus_id]["source_id"][2] = new_bus_number
        network_manager.config["bus"][new_bus_id]["index"] = new_bus_number
        network_manager.config["bus"][new_bus_id]["bus_i"] = new_bus_number
    end

    # Calculate ID of new branch based on which bus is configuring line.
    branch_bar_number = int_id + n_branches + int_calling_bus
    branch_bar_id = string(branch_bar_number)

    branch_info = deepcopy(network_manager.config["branch"][id])

    # If busbar connected to bus, add/remove edge/edges accordingly.
    if network_manager.busbar_connected[configuration.calling_bus]

        # Make new branch if needed.
        if !haskey(network_manager.config, branch_bar_id)

            network_manager.config["branch"][branch_bar_id] = deepcopy(branch_info)
            
            network_manager.config["branch"][branch_bar_id]["source_id"][2] = parse(Int, branch_bar_id)
            network_manager.config["branch"][branch_bar_id]["index"] = parse(Int, branch_bar_id)

            if branch_info["t_bus"] == configuration.calling_bus
                network_manager.config["branch"][branch_bar_id]["t_bus"] = new_bus_number
            elseif branch_info["f_bus"] == configuration.calling_bus
                network_manager.config["branch"][branch_bar_id]["f_bus"] = new_bus_number
            end

        end

        # Turn original branch on or off, as well as new branch.
        network_manager.config["branch"][id]["br_status"] = configuration.on_decision
        network_manager.config["branch"][branch_bar_id]["br_status"] = configuration.on_decision

    else

        # Delete busbar branch if exists.
        delete!(network_manager.config["branch"], branch_bar_id)

        # Turn branch on/off.
        network_manager.config["branch"][id]["br_status"] = configuration.on_decision
        
        # Connect branch to appropriate bus.
        if branch_info["t_bus"] == parse(Int, configuration.calling_bus)
            network_manager.config["branch"][id]["t_bus"] = (configuration.bus_decision == 0) ? bus_number : new_bus_number
        elseif branch_info["f_bus"] == parse(Int, configuration.calling_bus)
            network_manager.config["branch"][id]["f_bus"] = (configuration.bus_decision == 0) ? bus_number : new_bus_number
        end

    end

    config_result = solve_opf(network_manager.config, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>200, "print_level"=>0), setting = Dict("output" => Dict("duals" => true)))

    # Check if configuration was infeasible.
    if occursin("INFEASIBLE", string(config_result["termination_status"])) || occursin("ITERATION_LIMIT", string(config_result["termination_status"]))
        result = solve_opf(network_manager_save.config, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>200, "print_level"=>0))
        network_manager = network_manager_save
        return result["objective"]
    elseif occursin("ERROR", string(config_result["termination_status"]))
        result = solve_opf(network_manager_save.config, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>200, "print_level"=>0))
        network_manager = network_manager_save
        return result["objective"]
    else
        network_manager.config_sol = config_result["solution"]
        return config_result["objective"]
    end

end


function get_branch_components(network_manager)
    
    branch_components = []

    for (branch_key, branch_data_dict) in network_manager.network_sol["branch"]

        parameter_data = [Float64.(v) for v in collect(values(network_manager.network["branch"][branch_key])) if v isa Number]
        opt_data = collect(values(branch_data_dict))

        append!(branch_components, [Component(parameter_data, opt_data, branch_key)])

    end

    return branch_components

end

function get_branch_component(network_manager, branch_id::String, calling_bus::String)
    
    n_branches = length(network_manager.network["branch"])

    # Get easy parameter and standard branch data.
    parameter_data = [Float64.(v) for v in collect(values(network_manager.network["branch"][branch_id])) if v isa Number]

    # Get data from busbar branch - if branch doesn't exist, fill part of state with zeros.
    branch_bar_id = string(parse(Int, calling_bus) + n_branches + parse(Int, branch_id))

    opt_data = []
    # println(network_manager.config_sol["bus"])
    if haskey(network_manager.config_sol["branch"], branch_id)
        t_bus = string(network_manager.config["branch"][branch_id]["t_bus"])
        f_bus = string(network_manager.config["branch"][branch_id]["f_bus"])
        append!(opt_data, collect(values(network_manager.config_sol["branch"][branch_id])))
        append!(opt_data, haskey(network_manager.config_sol["bus"], f_bus) ? collect(values(network_manager.config_sol["bus"][f_bus])) : zeros(4))
        append!(opt_data, haskey(network_manager.config_sol["bus"], t_bus) ? collect(values(network_manager.config_sol["bus"][t_bus])) : zeros(4))
    else
        append!(opt_data, zeros(12))
    end

    if haskey(network_manager.config_sol["branch"], branch_bar_id)
        t_bus_bar = string(network_manager.config["branch"][branch_bar_id]["t_bus"])
        f_bus_bar = string(network_manager.config["branch"][branch_bar_id]["f_bus"])
        append!(opt_data, collect(values(network_manager.config_sol["branch"][branch_bar_id])))
        append!(opt_data, haskey(network_manager.config_sol["bus"], f_bus_bar) ? collect(values(network_manager.config_sol["bus"][f_bus_bar])) : zeros(4))
        append!(opt_data, haskey(network_manager.config_sol["bus"], t_bus_bar) ? collect(values(network_manager.config_sol["bus"][t_bus_bar])) : zeros(4))
    else
        append!(opt_data, zeros(12))
    end

    return Component(parameter_data, opt_data, branch_id)

end


function action_to_branch_configuration(branch_id::String, calling_bus::String, action::Int)

    return BranchConfiguration(branch_id, calling_bus, (action >>> 0) & 1, (action >>> 1) & 1)

end


mutable struct BranchEnv <: AbstractEnv
    action_space::Vector{Int}
    state_space::Space{Vector{ClosedInterval{Float64}}}
    action::Int
    state::Vector{Float64}
    reward::Float64
    n_actions::Int
    network_manager::NetworkManager
    bus_number::String
    branch_number::String
    is_done::Bool
    time::Int
    prev_cost::Float64
end

function create_branch_env(path::String)

    # Parse and solve original OPF problem instance.
    network_manager = create_network_manager(PowerModels.parse_file(path))
    result = solve_opf(network_manager.network, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0), setting = Dict("output" => Dict("duals" => true)))

    # Number of buses.
    n_buses = length(network_manager.network["bus"])
    # println(power_network["gen"])

    # Select random bus and a random branch at that bus.
    bus_number = string(rand(1:n_buses))
    branch_number = rand(get_adjacent_branch_ids(network_manager.network, parse(Int, bus_number)))

    # Set initial reward.
    reward = 0
    previous_cost = result["objective"]

    # All possible actions - for branch config, four possible configurations.
    n_actions = 4
    action_space = Base.OneTo(n_actions)
    
    # Map state to state represented by current powerflow solution.
    component = get_branch_component(network_manager, branch_number, bus_number)
    state = [component.parameter_data; component.opt_data]
    # println(state)
    
    state_space = Space(fill(-Inf64..Inf64, length(state)))

    return BranchEnv(   action_space,
                        state_space,
                        0,
                        state,
                        reward,
                        n_actions,
                        network_manager,
                        bus_number,
                        branch_number,
                        false,
                        0,
                        previous_cost)
end


function create_branch_env(path::String, bus_number::String, branch_number::String)

    # Parse and solve original OPF problem instance.
    network_manager = create_network_manager(PowerModels.parse_file(path))
    result = solve_opf(network_manager.network, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0), setting = Dict("output" => Dict("duals" => true)))

    # Number of buses.
    n_buses = length(network_manager.network["bus"])
    # println(power_network["gen"])

    # Set initial reward.
    reward = 0
    previous_cost = result["objective"]

    # All possible actions - for branch config, four possible configurations.
    n_actions = 4
    action_space = Base.OneTo(n_actions)
    
    # Map state to state represented by current powerflow solution.
    component = get_branch_component(network_manager, branch_number, bus_number)
    state = [component.parameter_data; component.opt_data]
    println(component.opt_data)
    
    state_space = Space(fill(-Inf64..Inf64, length(state)))

    return BranchEnv(   action_space,
                        state_space,
                        0,
                        state,
                        reward,
                        n_actions,
                        network_manager,
                        bus_number,
                        branch_number,
                        false,
                        0,
                        previous_cost)
end


function RLBase.action_space(env::BranchEnv)
    return env.action_space
end


function RLBase.state(env::BranchEnv)
    return env.state
end


function RLBase.state_space(env::BranchEnv)
    return env.state_space
end


function RLBase.reward(env::BranchEnv)
    return env.reward
end

function RLBase.is_terminated(env::BranchEnv)
    return env.is_done
end


function RLBase.reset!(env::BranchEnv)

    network_manager = create_network_manager(env.network_manager.network)
    env.network_manager = network_manager
    n_buses = length(keys(env.network_manager.network["bus"]))

    # Select random bus and a random branch at that bus.
    env.bus_number = string(rand(1:n_buses))
    env.branch_number = rand(get_adjacent_branch_ids(env.network_manager.network, parse(Int, env.bus_number)))

    # Parse and solve original OPF problem instance.
    # config_template = make_configuration_template(env.power_network, env.bus_number)
    # network_data = apply_bus_configuration(env.power_network, config_template)
    # env.network_manager = create_network_manager(env.network_manager.network)

    do_nothing_config = BranchConfiguration(env.branch_number, env.bus_number, 0, 1)
    objective_value = configure_and_resolve!(env.network_manager, do_nothing_config)

    component = get_branch_component(env.network_manager, env.branch_number,  env.bus_number)

    # Map state to state represented by current powerflow solution.
    env.state = [component.parameter_data; component.opt_data]

    # Reset is_done.
    env.is_done = false
    env.time = 0

    # Reset current action (set to the "do nothing" action).
    env.action = 0

    # Set reward to negative cost of original OPF cost.
    env.reward = 0
    env.prev_cost = objective_value

end


function (env::BranchEnv)(action)
    
    env.time += 1
    n_buses = length(keys(env.network_manager.network["bus"]))

    # If reward doesn't improve (no improvement in optimization solution), finish.
    # if (env.action == action) || (env.time >= 5)
    # if env.time >= 4
    if env.time >= 1
        env.is_done = true
    end

    # Store action.
    env.action = action

    # println(action)

    configuration = action_to_branch_configuration(env.branch_number, env.bus_number, action)
    solution_cost = configure_and_resolve!(env.network_manager, configuration)
    # print(env.network_manager.config["bus"])

    # Could modify current bus and current branch after every action - selected at random or with extra policy.
    # env.bus_number = string(rand(1:n_buses))
    # env.branch_number = rand(get_adjacent_branch_ids(env.network_manager.network, parse(Int, env.bus_number)))
    

    component = get_branch_component(env.network_manager, env.branch_number, env.bus_number)
    env.state = [component.parameter_data; component.opt_data]

    # Store previous reward before updating.
    previous_cost = copy(env.prev_cost)

    # Obtain reward by resolving with configuration determined by action. 
    env.reward = previous_cost - solution_cost
    # env.reward = (previous_cost - solution_cost) / solution_cost
    env.prev_cost = solution_cost

    # println(env.state)

end

@exportAll

end


# data_file = "..\\ieee_data\\pglib_opf_case14_ieee.m"
# network_manager = create_network_manager(PowerModels.parse_file(joinpath(@__DIR__, data_file)))
# branch_components = get_branch_components(network_manager)

# network_before = layout_network(deepcopy(network_manager.config))

# update_data!(network_before, network_manager.config_sol)

# before_plot = powerplot(   network_before;
#                             bus_data=:vm,
#                             bus_data_type=:quantitative,
#                             bus_color=["blue","red"],
#                             gen_data=:pg,
#                             gen_data_type=:quantitative,
#                             branch_data=:pt,
#                             branch_data_type=:quantitative,
#                             branch_color=["blue","red"],
#                             gen_color=["blue","red"],
#                             load_color="black",
#                             width=1200, 
#                             height=900,
#                             fixed=true,
#                             show_flow=false)

# test_branch_config = BranchConfiguration("9", "4", 1, 0)
# configure_and_resolve!(network_manager, test_branch_config)

# network_after = layout_network(deepcopy(network_manager.config))
# update_data!(network_after, network_manager.config_sol)

# copy_bus_layout_positions!(network_before, network_after)

# after_plot = powerplot(     network_after;
#                             bus_data=:vm,
#                             bus_data_type=:quantitative,
#                             bus_color=["blue","red"],
#                             gen_data=:pg,
#                             gen_data_type=:quantitative,
#                             branch_data=:pt,
#                             branch_data_type=:quantitative,
#                             branch_color=["blue","red"],
#                             gen_color=["blue","red"],
#                             load_color="black",
#                             width=1200, 
#                             height=900,
#                             fixed=true,
#                             show_flow=false)

# component = get_branch_component(network_manager, "9", "4")
