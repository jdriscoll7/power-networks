module NetworkFunctions

using Graphs
using DataStructures
using Plots


function distance_dict(graph, vertex::Int64)
    return Graphs.gdistances(graph, vertex)
end

function graph_distances(graph, vertices::Vector{Int64})
    
    distances = Graphs.gdistances(graph, vertices[1])
    for v in vertices[2:end]
        next_distances = Graphs.gdistances(graph, v)
        for (i, distance) in enumerate(next_distances)
            if distance < distances[i]
                distances[i] = distance
            end
        end
    end
    
    return distances
end


function power_to_graph(power_network)

    edges = Edge.([(x["f_bus"], x["t_bus"]) for (i, x) in power_network["branch"]])

    return Graphs.SimpleGraphs.SimpleGraph(edges)

end


function generate_distance_change_plot(graph, change_graph, removed_buses)

    simple_graph = power_to_graph(graph)
    distances = graph_distances(simple_graph, removed_buses)
    println(distances)

    distance_change_dict = Dict()

    for (vertex, distance) in enumerate(distances)
        if distance != 0
            vm = change_graph["bus"][string(vertex)]["vm"]
            va = change_graph["bus"][string(vertex)]["va"]
            if distance in keys(distance_change_dict)
                push!(distance_change_dict[distance], vm)
            else
                distance_change_dict[distance] = [vm]
            end
            
        end
    end

    x_data = vec([[d for x in x_list] for (d, x_list) in distance_change_dict])
    y_data = vec([x_list for (d, x_list) in distance_change_dict])

    scatter1 = scatter(x_data, y_data, seriestype=:scatter, legend=false, mode="markers", 
                    color=RGB(0.121,0.467,0.706), markerstrokewidth = 0, markersize=6, grid=false,
                    xticks=[2, 4, 6, 8, 10, 12],
                    xlabel="Solution Distance in Graph",
                    ylabel="Magnitude of Solution Change",
                    xguidefontsize=8,
                    yguidefontsize=8,
                    title="Position Change in Graph vs. Distance",
                    titlefontsize=10)
    
    display(scatter1)
    savefig(scatter1, "output_figs/power_change_plot.png")

    x_data = vec([d for (d, x_list) in distance_change_dict])
    y_data = vec([maximum(x_list) for (d, x_list) in distance_change_dict])

    scatter2 = scatter(x_data, y_data, seriestype=:scatter, legend=false, mode="markers", 
                    color=RGB(0.121,0.467,0.706), markerstrokewidth = 0, markersize=6, grid=false,
                    xticks=[2, 4, 6, 8, 10, 12],
                    xlabel="Solution Distance in Graph",
                    ylabel="Magnitude of Solution Change",
                    xguidefontsize=8,
                    yguidefontsize=8,
                    title="Largest Position Change in Graph vs. Distance",
                    titlefontsize=10)

    display(scatter2)

    savefig(scatter2, "output_figs/power_change_plot_max.png")

    return Dict(distance_change_dict)

end


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
            out_data["gen"][gen_key]["qg"] = -gen1[gen_key]["qg"] + gen2[gen_key]["qg"]
            out_data["gen"][gen_key]["pg"] = -gen1[gen_key]["pg"] + gen2[gen_key]["pg"]
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

function get_adjacent_branches(network, bus_number::Int)

    output_branch_list = {}

    for (bus_id, bus_info) in network["bus"]
        if bus_info["f_bus"] == bus_number || bus_info["t_bus"] == bus_number
            output_branch_list[bus_id] = copy(bus_info)
        end
    end

    return output_branch_list

end


function get_adjacent_branches(network, bus_number::String)

    return get_adjacent_branches(network, parse(Int, bus_number))

end


function get_adjacent_generators(network, bus_number::Int)

    output_gen_list = {}

    for (gen_id, gen_info) in network["gen"]
        if gen_info["gen_bus"] == bus_number 
            output_gen_list[gen_id] = copy(gen_info)
        end
    end

    return output_gen_list

end


function get_adjacent_generators(network, bus_number::String)

    return get_adjacent_generators(network, parse(Int, bus_number))

end

function get_adjacent_loads(network, bus_number::Int)

    output_load_list = {}

    for (load_id, load_info) in network["load"]
        if load_info["load_bus"] == bus_number 
            output_load_list[load_id] = copy(load_info)
        end
    end

    return output_load_list

end


function get_adjacent_loads(network, bus_number::String)

    return get_adjacent_loads(network, parse(Int, bus_number))

end


end