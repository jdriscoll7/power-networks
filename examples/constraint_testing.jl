using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite

includet("../src/NetworkFunctions.jl")
using .NetworkFunctions
default(show = true)


# data_file = joinpath(@__DIR__, "..\\ieee_data\\WB5.m")
# network_data_1 = PowerModels.parse_file(data_file)
# network_data_2 = PowerModels.parse_file(data_file)
# delete!(network_data_2["branch"], "6")

data_file = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case5_pjm.m")
network_data_1 = PowerModels.parse_file(data_file)
network_data_2 = PowerModels.parse_file(data_file)
power_to_graph(network_data_2)
# delete!(network_data_2["branch"], "7")
delete!(network_data_2["branch"], "148")


result_1 = solve_opf(network_data_1, ACPPowerModel, Ipopt.Optimizer)
result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)

println("Original objective value: " * string(result_1["objective"]))
println("New objective value: " * string(result_2["objective"]))

update_data!(network_data_1, result_1["solution"])
update_data!(network_data_2, result_2["solution"])
network_data_1 = layout_network(network_data_1; layout_algorithm=Spectral)
network_data_2 = layout_network(network_data_2; layout_algorithm=Spectral)

change_data_12 = NetworkFunctions.generate_change_data(network_data_1, network_data_2)

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

plot2 = powerplot(  network_data_2,
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
                

display(plot2)

plot3 = powerplot(  change_data_12;
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

display(plot3)