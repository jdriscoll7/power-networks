using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite

include("../src/NetworkFunctions.jl")
using ..NetworkFunctions
default(show = true)


data_file = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case118_ieee.m")

EXPERIMENT_MODE = "single branch"

network_data_1 = PowerModels.parse_file(data_file)
network_data_2 = PowerModels.parse_file(data_file)
network_data_3 = PowerModels.parse_file(data_file)

result_1 = solve_opf(network_data_1, ACPPowerModel, Ipopt.Optimizer)
update_data!(network_data_1, result_1["solution"])
network_data_1 = layout_network(network_data_1)

plot1 = powerplot(  network_data_1,
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["black","black","red"],
                        gen_color=["black","black","red"],
                        load_color="blue",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

display(plot1)
save("output_figs/power_solution.png", plot1)


if EXPERIMENT_MODE == "bus"
    #delete!(network_data_2["branch"], "6")
    NetworkFunctions.delete_bus(network_data_2, "32")
    NetworkFunctions.delete_bus(network_data_3, "32")
    NetworkFunctions.delete_bus(network_data_3, "5")

    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)
    result_3 = solve_opf(network_data_3, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])
    update_data!(network_data_3, result_3["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)
    # network_data_3 = layout_network(network_data_3)

    plot2 = powerplot(  network_data_2,
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["black","black","red"],
                        gen_color=["black","black","red"],
                        load_color="black",
                        width=1200, 
                        height=900)

    change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)
    change_data_13 = NetworkFunctions.generate_change_data(network_data_1, network_data_3)
    change_data_23 = NetworkFunctions.generate_change_data(network_data_2, network_data_3)

    plot3 = powerplot(  change_data_12;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

    plot4 = powerplot(  change_data_23;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

    plot5 = powerplot(  change_data_13;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

elseif EXPERIMENT_MODE == "single bus"
    buses_to_remove = [28, 115]
    for b in buses_to_remove
        NetworkFunctions.delete_bus(network_data_2, string(b))
    end
    
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)

    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)

    distance_table = NetworkFunctions.generate_distance_change_plot(network_data_1, change_data_12, buses_to_remove)


    plot3 = powerplot(  change_data_12;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)
    display(plot3)
    save("output_figs/power_heatmap.png", plot3)

elseif EXPERIMENT_MODE == "multi bus"
    NetworkFunctions.delete_bus(network_data_2, "95")
    NetworkFunctions.delete_bus(network_data_2, "25")
    
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)

    distance_table = NetworkFunctions.generate_distance_change_plot(network_data_1, change_data_12, [95, 25])
    

    plot3 = powerplot(  change_data_12;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)
                    

elseif EXPERIMENT_MODE == "single branch"
    delete!(network_data_2["branch"], "140")
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)

    plot3 = powerplot(  change_data_12;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

elseif EXPERIMENT_MODE == "multi branch"
    delete!(network_data_2["branch"], "169")
    delete!(network_data_2["branch"], "5")
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)

    plot3 = powerplot(  change_data_12;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

elseif EXPERIMENT_MODE == "branch"

    delete!(network_data_2["branch"], "6")
    delete!(network_data_3["branch"], "6")
    delete!(network_data_3["branch"], "54")
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)
    result_3 = solve_opf(network_data_3, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])
    update_data!(network_data_3, result_3["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_1 = layout_network(network_data_1)
    network_data_2 = layout_network(network_data_2)

    plot2 = powerplot(  network_data_2,
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["black","black","red"],
                        gen_color=["black","black","red"],
                        width=1200, 
                        height=900)

    change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)
    change_data_13 = NetworkFunctions.generate_change_data(network_data_1, network_data_3)
    change_data_23 = NetworkFunctions.generate_change_data(network_data_2, network_data_3)

    plot3 = powerplot(  change_data_12;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

    plot4 = powerplot(  change_data_23;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

    plot5 = powerplot(  change_data_13;
                        bus_data=:vm,
                        bus_data_type=:quantitative,
                        bus_color=["blue","red"],
                        gen_data=:pg,
                        gen_data_type=:quantitative,
                        branch_data=:pt,
                        branch_data_type=:quantitative,
                        branch_color=["blue","red"],
                        gen_color=["blue","red"],
                        load_color="black",
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)

elseif EXPERIMENT_MODE == "gen"
    println("not implemented yet")
end
