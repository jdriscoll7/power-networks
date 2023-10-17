module Configurations

using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite
using ExportAll
using JuMP
using Revise

include("./NetworkFunctions.jl")
using .NetworkFunctions


mutable struct Configuration
    bus_number::Int
    buses_connected::Int
    load_connections::Array{Int}
    gen_connections::Array{Int}
    line_to_bus_connections::Array{Int}
    line_connections::Array{Int}
end


function apply_bus_configuration(network, configuration)

    # Initialize output.
    output_network = deepcopy(network)

    bus_number = configuration.bus_number

    # Create new bus for the system, determine numbering based on n_buses.
    n_buses = length(network["bus"])
    n_branches = length(network["branch"])
    new_bus_number = bus_number + n_buses

    output_network["bus"][string(new_bus_number)] = deepcopy(network["bus"][string(bus_number)])
    output_network["bus"][string(new_bus_number)]["source_id"][2] = new_bus_number
    output_network["bus"][string(new_bus_number)]["index"] = new_bus_number
    output_network["bus"][string(new_bus_number)]["bus_i"] = new_bus_number

    # Setup branches.

    # Collect adjacent branches for bus.
    adjacent_branches = get_adjacent_branches(network, bus_number)
    sorted_adjacent_branch_keys = sort(parse.(Int, collect(keys(adjacent_branches))))

    # First remove all branches that are turned off.
    for config_id = 1:length(configuration.line_connections)
        if configuration.line_connections[config_id] == 0
            delete!(output_network["branch"], string(sorted_adjacent_branch_keys[config_id]))
        end
    end

    # If buses are connected, don't change existing bus. Copy all branches to second bus - ignore line_to_bus_connections field.
    if configuration.buses_connected != 0

        adjacent_branches = get_adjacent_branches(output_network, bus_number)
        sorted_adjacent_branch_keys = sort(parse.(Int, collect(keys(adjacent_branches))))    

        branches_to_add = create_new_branches(adjacent_branches, bus_number, new_bus_number, n_branches)
        
        for (branch_id, branch_info) in branches_to_add
            output_network["branch"][branch_id] = branch_info
        end

    # If buses are not connected, must look at line_to_bus_connections field.
    else

        for config_id = 1:length(configuration.line_to_bus_connections)
            if configuration.line_to_bus_connections[config_id] != 0
                
                # println(config_id)
                # println(configuration.line_connections)
                

                if configuration.line_connections[config_id] == 0
                    continue
                end
                
                branch_key = string(sorted_adjacent_branch_keys[config_id])
                # println(branch_key)

                # For each branch, decide if t_bus or f_bus needs to be switched to new bus number.
                if bus_number == output_network["branch"][branch_key]["t_bus"]
                    output_network["branch"][branch_key]["t_bus"] = new_bus_number
                else
                    output_network["branch"][branch_key]["f_bus"] = new_bus_number
                end

            end
        end

    end

    # Setup generator and load connections.
    adjacent_generators = get_adjacent_generators(output_network, bus_number)
    adjacent_loads = get_adjacent_loads(output_network, bus_number)

    sorted_gen_keys = sort(collect(keys(adjacent_generators)))
    sorted_load_keys = sort(collect(keys(adjacent_loads)))

    for config_id = 1:length(configuration.gen_connections)
        choice = configuration.gen_connections[config_id]
        if choice != 0
            output_network["gen"][sorted_gen_keys[config_id]]["gen_bus"] = new_bus_number
        end
    end

    for config_id = 1:length(configuration.load_connections)
        choice = configuration.load_connections[config_id]
        if choice != 0
            output_network["load"][sorted_load_keys[config_id]]["load_bus"] = new_bus_number
        end
    end

    return output_network

end


function solve_configuration(network, configuration)

    return solve_configuration(apply_bus_configuration(network, configuration))

end

function solve_configuration(configured_network)

    opt = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0)

    return solve_opf(configured_network, ACPPowerModel, opt)

end


function analyze_configuration(network_solution,  reconfigured_solution, network, reconfigured_network)

    reconfigured_network = layout_network(reconfigured_network)
    overwrite_layout_positions!(network, reconfigured_network)

    plot_1 = powerplot( network;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue", "yellow"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

    display(plot_1)

    plot_2 = powerplot( reconfigured_network;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue", "yellow"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

    display(plot_2)

    println("Original Objective Value: " * string(network_solution["objective"]) * "\n Reconfigured Objective Value: " * string(reconfigured_solution["objective"]))

end


function analyze_configuration(network, configuration)

    output_network = deepcopy(network)
    output_configured_network = apply_bus_configuration(network, configuration)
    
    network_solution = solve_opf(network, ACPPowerModel, Ipopt.Optimizer)
    reconfigured_solution = solve_configuration(network, configuration)

    update_data!(output_network, network_solution["solution"])
    update_data!(output_configured_network, reconfigured_solution["solution"])

    analyze_configuration(network_solution, reconfigured_solution, output_network, output_configured_network)

end


function configuration_cost(network, configuration)

    output_configured_network = apply_bus_configuration(network, configuration)
    result = solve_opf(network, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0))
    

    reconfigured_solution = solve_configuration(network, configuration)

    update_data!(output_configured_network, reconfigured_solution["solution"])
    update_data!(network, result["solution"])

    if occursin("INFEASIBLE", string(reconfigured_solution["termination_status"])) || occursin("ITERATION_LIMIT", string(reconfigured_solution["termination_status"]))
        return result["objective"], network
    elseif occursin("ERROR", string(reconfigured_solution["termination_status"]))
        return result["objective"], network
    else
        return reconfigured_solution["objective"], output_configured_network
    end
end


function create_new_branches(branch_list, old_id, new_id, n_branches)

    output_branch_list = Dict()

    for (branch_id, branch_info) in branch_list
        
        new_branch_id = string(n_branches + parse(Int, branch_id))
        output_branch_list[new_branch_id] = deepcopy(branch_info)
        output_branch_list[new_branch_id]["source_id"][2] = parse(Int, new_branch_id)
        output_branch_list[new_branch_id]["index"] = parse(Int, new_branch_id)


        if branch_info["t_bus"] == old_id
            output_branch_list[new_branch_id]["t_bus"] = new_id

        elseif branch_info["f_bus"] == old_id
            output_branch_list[new_branch_id]["f_bus"] = new_id

        end
        
    end

    return output_branch_list

end


function make_configuration_template(network, bus; connected=0)

    # Count number of loads, generators, branches.
    n_loads = length(get_adjacent_loads(network, bus))
    n_gens = length(get_adjacent_generators(network, bus))
    n_branches = length(get_adjacent_branches(network, bus))
    
    # Initialize buses to not be connected.
    buses_connected = connected

    load_connections = zeros(n_loads, 1)
    gen_connections = zeros(n_gens, 1)
    line_to_bus_connections = zeros(n_branches, 1)

    # Initialize all branches to be on.
    line_connections = ones(n_branches, 1)

    return Configuration(bus, buses_connected, load_connections, gen_connections, line_to_bus_connections, line_connections)
end


function generate_all_configurations(network, bus)

    # Output config list.
    output_configs = []
    
    # Config to use as basis for others.
    starting_config = make_configuration_template(network, bus)

    # println(starting_config)

    # Compute total number of configurations.
    n_config_bits = 1 + length(starting_config.load_connections) + length(starting_config.gen_connections) + length(starting_config.line_to_bus_connections) + length(starting_config.line_connections)

    # println(n_config_bits)

    for i = 1:(2^n_config_bits)
        push!(output_configs, binary_to_configuration(starting_config, i))
    end

    return output_configs

end


function binary_to_configuration(config, binary_string)

    output_config = deepcopy(config)

    bit_index = 0

    for i=1:length(config.line_connections)
        output_config.line_connections[i] = (((binary_string & (1 << bit_index))) == 0) ? 0 : 1
        bit_index += 1
    end
    for i=1:length(config.line_to_bus_connections)
        output_config.line_to_bus_connections[i] = (((binary_string & (1 << bit_index))) == 0) ? 0 : 1
        bit_index += 1
    end
    for i=1:length(config.gen_connections)
        output_config.gen_connections[i] = (((binary_string & (1 << bit_index))) == 0) ? 0 : 1
        bit_index += 1
    end
    for i=1:length(config.load_connections)
        output_config.load_connections[i] = (((binary_string & (1 << bit_index))) == 0) ? 0 : 1
        bit_index += 1
    end
    
    # Single bit.
    output_config.buses_connected = (((binary_string & (1 << bit_index))) == 0) ? 0 : 1    

    return output_config

end


@exportAll()

end