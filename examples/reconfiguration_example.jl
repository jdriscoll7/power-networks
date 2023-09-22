using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite
using Revise

includet("../src/NetworkFunctions.jl")
includet("../src/Configurations.jl")
using .NetworkFunctions
using .Configurations

default(show = true)

# data_file = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case5_pjm.m")
# data_file = joinpath(@__DIR__, "..\\ieee_data\\WB5.m")
data_file = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case30_ieee.m")
network_data = PowerModels.parse_file(data_file)


# BUS_NUMBERS = [15, 24, 9, 17]
BUS_NUMBERS = [2, 27]

config_costs = Dict()
configs = Dict()

for b_number in BUS_NUMBERS
    
    config_costs[b_number] = Dict()
    configs[b_number] = generate_all_configurations(network_data, b_number)

    for (i, config) in enumerate(configs[b_number])
        config_costs[b_number][i] = configuration_cost(network_data, config)[1]
    end

end

for b_number in BUS_NUMBERS
    println("Bus: " * string(b_number))
    for (i, config_cost) in config_costs[b_number]
        println(string(i) * ": " * string(config_cost))
    end
    println("\n")

    filtered_config_costs = filter(((k,v),) -> !isnan(v), config_costs[b_number])
    (min_val, min_key) = findmin(filtered_config_costs)

    analyze_configuration(network_data, configs[b_number][min_key])
    println("\n")
end



# config = make_configuration_template(network_data, 3)
# config.buses_connected = 1
# config.line_connections[end] = 0

# configured_network = apply_bus_configuration(network_data, config)

# result = analyze_configuration(network_data, config)