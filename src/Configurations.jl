using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite

include("NetworkFunctions.jl")
using .NetworkFunctions


mutable struct Configuration
    buses_connected::UInt8
    load_connections::Array{UInt8}
    gen_connections::Array{UInt8}
    line_to_bus_connections::Array{UInt8}
    line_connections::Array{UInt8}
end


function apply_bus_configuration(network, configuration, bus_number)

    # Initialize output.
    output_network = copy(network)

    # Create new bus for the system, determine numbering based on n_buses.
    n_buses = length(network["bus"])
    new_bus_number = bus_number + n_buses

    output_network["bus"][string(new_bus_number)] = copy(network["bus"][string(bus_number)])

    # Setup branches.

    # First remove all branches that are turned off.
    for branch_id = 1:length(configuration.line_connections)
        if configuration.line_connections[branch_id] == 0
            delete!(output_network["branch"], string(branch_id))
        end
    end

    # Collect adjacent branches for bus.
    adjacent_branches = get_adjacent_branches(network, bus_number)

    # If buses are connected, don't change existing bus. Copy all branches to second bus - ignore line_to_bus_connections field.
    if configuration.buses_connected != 0

        branches_to_add = update_bus_ids(adjacent_branches, bus_number, new_bus_number)
        
        for (branch_id, branch_info) in branches_to_add
            output_network["branch"][branch_id] = branch_info
        end

    # If buses are not connected, must look at line_to_bus_connections field.
    else

        sorted_adjacent_branch_keys = sort(collect(keys(adjacent_branches)))

        for config_id = 1:length(configuration.line_to_bus_connections)
            if configuration.line_to_bus_connections[branch_id] != 0
                
                branch_key = sorted_adjacent_branch_keys[config_id]

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
    adjacent_generators = get_adjacent_generators(network, bus_number)
    adjacent_loads = get_adjacent_loads(network, bus_number)

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

end


function solve_configuration(network, configuration, bus_number)

    reconfigured_network = apply_bus_configuration(network, configuration, bus_number)

    return solve_opf(reconfigured_network, ACPPowerModel, Ipopt.Optimizer)

end


function analyze_configuration(network_solution,  reconfigured_solution)

    plot_1 = powerplot( network_solution;
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

    plot_2 = powerplot( reconfigured_solution;
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
    display(plot_2)

    println("Original Objective Value: " * network_solution["objective"] * "\n Reconfigured Objective Value: " * reconfigured_solution["objective"])

end


function analyze_configuration(network, configuration, bus_number)

    network_solution = solve_opf(network, ACPPowerModel, Ipopt.Optimizer)
    reconfigured_solution = solve_configuration(network, configuration, bus_number)

    analyze_configuration(network_solution, reconfigured_solution)

end


function update_bus_ids(branch_list, old_id, new_id)

    output_branch_list = copy(branch_list)

    for (branch_id, branch_info) in branch_list
        
        if branch_info["t_bus"] == old_id
            output_branch_list[branch_id]["t_bus"] = new_id

        elseif branch_info["f_bus"] == old_id
            output_branch_list[branch_id]["f_bus"] = new_id

        end
        
    end

end