using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite
using JuMP

include("../src/NetworkFunctions.jl")
using ..NetworkFunctions
default(show = true)

function is_infeasible_result(result)

    # print(string(result["termination_status"]))

    if occursin("INFEASIBLE", string(result["termination_status"])) || occursin("ITERATION_LIMIT", string(result["termination_status"]))
        return true
    elseif occursin("ERROR", string(result["termination_status"]))
        return true
    else
        return false
    end

end


test_cases = ["..\\ieee_data\\pglib_opf_case14_ieee.m", 
              "..\\ieee_data\\pglib_opf_case30_ieee.m", 
              "..\\ieee_data\\pglib_opf_case57_ieee.m", 
              "..\\ieee_data\\pglib_opf_case118_ieee.m"]

# test_cases = ["..\\ieee_data\\pglib_opf_case30_ieee.m"]
data_files = [joinpath(@__DIR__, t) for t in test_cases]

# List of x and y data to plot later.
x_data = Dict()
y_data = Dict()

for data_file in data_files

    # Need to add this key and empty list into x and y data dicts - keys represent test case.
    x_data[data_file] = []
    y_data[data_file] = []

    network_data_1 = PowerModels.parse_file(data_file)
    result_1 = solve_opf(network_data_1, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>600, "print_level"=>0))
    update_data!(network_data_1, result_1["solution"])
    network_data_1 = layout_network(network_data_1)

    println("Running $data_file")

    for i_bus = 1:length(keys(network_data_1["bus"]))
        
        changed_network = deepcopy(network_data_1)

        # Delete a bus and re-solve - check to see if it is feasible network configuration.
        NetworkFunctions.delete_bus(changed_network, string(i_bus))
        changed_result = solve_opf(changed_network, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>600, "print_level"=>0))
        if is_infeasible_result(changed_result)
            continue
        end

        update_data!(changed_network, changed_result["solution"])

        # Compute positional layout for plotting based on original network.
        changed_network = layout_network(changed_network)
        change_data = NetworkFunctions.generate_change_data(network_data_1, changed_network)

        # Compute xy data for plotting distance vs change plots.
        _x_data, _y_data = NetworkFunctions.generate_distance_change_plot(network_data_1, change_data, [i_bus], return_xy_data=true)
        println(_x_data)
        println(_y_data)
        # Add to appropriate dict/lists.
        append!(x_data[data_file], [_x_data])
        append!(y_data[data_file], [_y_data])

        # plot3 = powerplot(  change_data;
        #                     bus_data=:vm,
        #                     bus_data_type=:quantitative,
        #                     bus_color=["blue","red"],
        #                     gen_data=:pg,
        #                     gen_data_type=:quantitative,
        #                     branch_data=:pt,
        #                     branch_data_type=:quantitative,
        #                     branch_color=["blue","red"],
        #                     gen_color=["blue","red"],
        #                     load_color="black",
        #                     width=1200, 
        #                     height=900,
        #                     fixed=true,
        #                     show_flow=false)

        # display(plot3)

    end
end


# Plot everything.
for data_file in data_files

    y_data[data_file] = y_data[data_file][1:6]
    x_data[data_file] = x_data[data_file][1:6]

    network_data_1 = PowerModels.parse_file(data_file)
    n_buses = length(keys(network_data_1["bus"]))
    scatter_plot = nothing;

    for (i, _y_data) in enumerate(y_data[data_file])

        _x_data = x_data[data_file][i]

        sorted_idx = sortperm(_x_data)
        sorted_x = _x_data[sorted_idx]
        sorted_y = log.(_y_data[sorted_idx] .+ 1e-3)

        println(sorted_y)

        # scatter_plot =  scatter(_x_data, _y_data, seriestype=:scatter, legend=false, mode="markers", 
        #                         color=RGB(0.121,0.467,0.706), markerstrokewidth = 0, markersize=6, grid=false,
        #                         # xticks=[2, 4, 6, 8, 10, 12, 14, 16],
        #                         xlabel="Solution Distance in Graph",
        #                         ylabel="Magnitude of Solution Change",
        #                         xguidefontsize=8,
        #                         yguidefontsize=8,
        #                         title="Largest Position Change in Graph vs. Distance",
        #                         titlefontsize=10)
        
        if (i == 1)
            scatter_plot = plot(    sorted_x, sorted_y,  legend=false, mode="markers", 
                                    color=i, markerstrokewidth = 6, markersize=6, grid=false,
                                    xlabel="Distance in Graph",
                                    ylabel="Magnitude of Solution Change",
                                    xguidefontsize=8,
                                    yguidefontsize=8,
                                    title="Largest Change vs. Distance ($n_buses Bus Test Case)",
                                    titlefontsize=10)
        
        elseif (i == length(keys(y_data[data_file])))
            display(scatter_plot)
        else
            plot!(  sorted_x, sorted_y, legend=false, mode="markers", 
                    color=i, markerstrokewidth = 6, markersize=6, grid=false,
                    xlabel="Distance in Graph",
                    ylabel="Magnitude of Solution Change",
                    xguidefontsize=8,
                    yguidefontsize=8,
                    title="Largest Change vs. Distance ($n_buses Bus Test Case)",
                    titlefontsize=10)
        end
    end
end
