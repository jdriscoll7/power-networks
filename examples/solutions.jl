using PowerModels
using PowerPlots
using Ipopt

function generate_change_data(data_1, data_2)

    # Collect bus, branch, load, and gen data.
    bus1, branch1, load1, gen1 = data_1["bus"], data_1["branch"], data_1["load"], data_1["gen"]
    bus2, branch2, load2, gen2 = data_2["bus"], data_2["branch"], data_2["load"], data_2["gen"]

    # Keep track of which network is larger.
    larger_data = 0

    if length(bus1) > length(bus2) || length(branch1) > length(branch2) || length(load1) > length(load2) || length(gen1) > length(gen2)
        out_data = deepcopy(data_2)
        larger_data = 1
    else
        out_data = deepcopy(data_1)
        larger_data = 2
    end

    # for j in removed_indices
    #     out_data["branch"]
    # end

    # Set bus changes.
    for bus_key in keys(larger_data!=1 ? bus1 : bus2)
        out_data["bus"][bus_key]["va"] = abs(bus1[bus_key]["va"] - bus2[bus_key]["va"])
        out_data["bus"][bus_key]["vm"] = abs(bus1[bus_key]["vm"] - bus2[bus_key]["vm"])
    end

    # Set branch changes.
    for branch_key in keys(larger_data!=1 ? branch1 : branch2)
        out_data["branch"][branch_key]["pt"] = abs(branch1[branch_key]["pt"] - branch2[branch_key]["pt"])
    end

    # Set load changes.
    for load_key in keys(larger_data!=1 ? load1 : load2)
        out_data["load"][load_key]["qd"] = abs(load1[load_key]["qd"] - load2[load_key]["qd"])
        out_data["load"][load_key]["pd"] = abs(load1[load_key]["pd"] - load2[load_key]["pd"])
    end

    # Set generator changes.
    for gen_key in keys(larger_data!=1 ? gen1 : gen2)
        out_data["gen"][gen_key]["qg"] = abs(gen1[gen_key]["qg"] - gen2[gen_key]["qg"])
        out_data["gen"][gen_key]["pg"] = abs(gen1[gen_key]["pg"] - gen2[gen_key]["pg"])
    end

    return out_data

end

data_file = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case14_ieee.m")

network_data_1 = PowerModels.parse_file(data_file)
network_data_2 = PowerModels.parse_file(data_file)

result_1 = solve_opf(network_data_1, ACPPowerModel, Ipopt.Optimizer)

delete!(network_data_2["branch"], "6")
result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)

update_data!(network_data_1, result_1["solution"])
update_data!(network_data_2, result_2["solution"])


plot1 = powerplot(  network_data_1,
                    bus_data=:vm,
                    bus_data_type=:quantitative,
                    gen_data=:pg,
                    gen_data_type=:quantitative,
                    branch_data=:pt,
                    branch_data_type=:quantitative,
                    branch_color=["black","black","red"],
                    gen_color=["black","black","red"],
                    width=1700, 
                    height=900)

plot2 = powerplot(  network_data_2,
                    bus_data=:vm,
                    bus_data_type=:quantitative,
                    gen_data=:pg,
                    gen_data_type=:quantitative,
                    branch_data=:pt,
                    branch_data_type=:quantitative,
                    branch_color=["black","black","red"],
                    gen_color=["black","black","red"],
                    width=1700, 
                    height=900)

change_data = generate_change_data(network_data_1, network_data_2)

plot3 = powerplot(  change_data,
                    bus_data=:vm,
                    bus_data_type=:quantitative,
                    gen_data=:pg,
                    gen_data_type=:quantitative,
                    branch_data=:pt,
                    branch_data_type=:quantitative,
                    branch_color=["black","white"],
                    gen_color=["black","white"],
                    width=1700, 
                    height=900)

plot1
plot3