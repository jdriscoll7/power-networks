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

    println("Larger data: "*string(larger_data))

    # Copy over positions to changed data to keep bus positions constant.
    for (bus_number, bus_data) in (larger_data==1 ? data_1 : data_2)["bus"]
        if bus_number in keys(out_data["bus"])
            out_data["bus"][bus_number]["xcoord_1"] = bus_data["xcoord_1"]
            out_data["bus"][bus_number]["ycoord_1"] = bus_data["ycoord_1"]
            
            data_1["bus"][bus_number]["xcoord_1"] = bus_data["xcoord_1"]
            data_1["bus"][bus_number]["ycoord_1"] = bus_data["ycoord_1"]
            data_2["bus"][bus_number]["xcoord_1"] = bus_data["xcoord_1"]
            data_2["bus"][bus_number]["ycoord_1"] = bus_data["ycoord_1"]
        end
    end

    for (load_number, load_data) in (larger_data==1 ? data_1 : data_2)["load"]
        if load_number in keys(out_data["load"])
            out_data["load"][load_number]["xcoord_1"] = load_data["xcoord_1"]
            out_data["load"][load_number]["ycoord_1"] = load_data["ycoord_1"]

            data_1["load"][load_number]["xcoord_1"] = load_data["xcoord_1"]
            data_1["load"][load_number]["ycoord_1"] = load_data["ycoord_1"]
            data_2["load"][load_number]["xcoord_1"] = load_data["xcoord_1"]
            data_2["load"][load_number]["ycoord_1"] = load_data["ycoord_1"]

        end
    end

    for (gen_number, gen_data) in (larger_data==1 ? data_1 : data_2)["gen"]
        if gen_number in keys(out_data["gen"])
            out_data["gen"][gen_number]["xcoord_1"] = gen_data["xcoord_1"]
            out_data["gen"][gen_number]["ycoord_1"] = gen_data["ycoord_1"]

            data_1["gen"][gen_number]["xcoord_1"] = gen_data["xcoord_1"]
            data_1["gen"][gen_number]["ycoord_1"] = gen_data["ycoord_1"]
            data_2["gen"][gen_number]["xcoord_1"] = gen_data["xcoord_1"]
            data_2["gen"][gen_number]["ycoord_1"] = gen_data["ycoord_1"]
            
        end
    end

    # Set bus changes.
    for bus_key in keys(larger_data!=1 ? bus1 : bus2)
        if bus_key in keys(out_data["bus"])
            out_data["bus"][bus_key]["va"] = abs(bus1[bus_key]["va"] - bus2[bus_key]["va"])
            out_data["bus"][bus_key]["vm"] = abs(bus1[bus_key]["vm"] - bus2[bus_key]["vm"])
        end
    end

    # Set branch changes.
    for branch_key in keys(larger_data!=1 ? branch1 : branch2)
        if branch_key in keys(out_data["branch"])
            out_data["branch"][branch_key]["pt"] = abs(branch1[branch_key]["pt"] - branch2[branch_key]["pt"])
        end
    end

    # Set load changes.
    for load_key in keys(larger_data!=1 ? load1 : load2)
        if load_key in keys(out_data["load"])
            out_data["load"][load_key]["qd"] = abs(load1[load_key]["qd"] - load2[load_key]["qd"])
            out_data["load"][load_key]["pd"] = abs(load1[load_key]["pd"] - load2[load_key]["pd"])
        end
    end

    # Set generator changes.
    for gen_key in keys(larger_data!=1 ? gen1 : gen2)
        if gen_key in keys(out_data["gen"])
            out_data["gen"][gen_key]["qg"] = abs(gen1[gen_key]["qg"] - gen2[gen_key]["qg"])
            out_data["gen"][gen_key]["pg"] = abs(gen1[gen_key]["pg"] - gen2[gen_key]["pg"])
        end
    end

    return out_data

end

function delete_bus(network_data, bus_id)

    # Remove branches.
    for (branch_id, branch) in network_data["branch"]
        if branch["f_bus"] == parse(Int64, bus_id) || branch["t_bus"] == parse(Int64, bus_id)
            delete!(network_data["branch"], branch_id)
        end
    end

    # Remove bus.
    delete!(network_data["bus"], bus_id)

    # Remove generators.
    for (gen_id, gen) in network_data["gen"]
        if gen["gen_bus"] == parse(Int64, bus_id)
            delete!(network_data["gen"], gen_id)
        end
    end

    # Remove loads.
    for (load_id, load) in network_data["load"]
        if load["load_bus"] == parse(Int64, bus_id)
            delete!(network_data["load"], load_id)
        end
    end

end

data_file = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case118_ieee.m")

EXPERIMENT_MODE = "multi bus"

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
                        width=1200, 
                        height=900,
                        fixed=true,
                        show_flow=false)


if EXPERIMENT_MODE == "bus"
    #delete!(network_data_2["branch"], "6")
    delete_bus(network_data_2, "32")
    delete_bus(network_data_3, "32")
    delete_bus(network_data_3, "5")

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
                        width=1200, 
                        height=900)

    change_data_12 = generate_change_data(network_data_1, network_data_2)
    change_data_13 = generate_change_data(network_data_1, network_data_3)
    change_data_23 = generate_change_data(network_data_2, network_data_3)

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
    delete_bus(network_data_2, "38")
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = generate_change_data(network_data_1, network_data_2)

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

elseif EXPERIMENT_MODE == "multi bus"
    delete_bus(network_data_2, "95")
    delete_bus(network_data_2, "25")
    
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = generate_change_data(network_data_1, network_data_2)

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
    delete!(network_data_2["branch"], "54")
    result_2 = solve_opf(network_data_2, ACPPowerModel, Ipopt.Optimizer)


    update_data!(network_data_2, result_2["solution"])

    # Compute positional layout for plotting based on original network.
    network_data_2 = layout_network(network_data_2)

    change_data_12 = generate_change_data(network_data_1, network_data_2)

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

    change_data_12 = generate_change_data(network_data_1, network_data_2)

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

    change_data_12 = generate_change_data(network_data_1, network_data_2)
    change_data_13 = generate_change_data(network_data_1, network_data_3)
    change_data_23 = generate_change_data(network_data_2, network_data_3)

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
