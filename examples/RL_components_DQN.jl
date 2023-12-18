# using Conda
using PowerModels
using PowerPlots
using Ipopt
using Printf
using Plots
using VegaLite
using ExportAll
using IntervalSets
using Flux: params
using JuMP
using ReinforcementLearning
# using Flux: InvDecay
using StableRNGs
using Flux
using Flux.Losses
using Statistics
using LaTeXStrings
# using PyPlot


includet("../src/NetworkFunctions.jl")
includet("../src/Configurations.jl")
includet("../src/ComponentsRL.jl")
using ..NetworkFunctions
using ..Configurations
using ..ComponentsRL


function branch_config_to_config(branch_config::BranchConfiguration)
    
    return Configuration(parse(Int, branch_config.calling_bus), 0, zeros(1, 10), zeros(1, 10), [branch_config.bus_decision], [branch_config.on_decision])

end


function run_inference(path::String, bus::String, branch::String, policy)
    
    env = create_branch_env(path, bus, branch);

    original_cost = env.prev_cost
    display(plot([policy(env) for _ in range(1, 1000)]))
    action = policy(env)
    return_config = action_to_branch_configuration(branch, bus, action)
    # println(return_config)
    # Step environment and solve/print objective value for configuration.
    env(action)
    println(env.reward)
    # display(powerplot(env.network_manager.config));
    network = copy(env.network_manager.network)
    config_network = copy(env.network_manager.config)
    network_sol = copy(env.network_manager.network_sol)
    config_sol = copy(env.network_manager.config_sol)

    update_data!(network, network_sol)
    update_data!(config_network, config_sol)

    config_network = layout_network(config_network)
    network = layout_network(network)
    overwrite_layout_positions!(network, config_network)

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

    plot_2 = powerplot( config_network;
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
                        # )

    display(plot_2)

    println("Original Objective Value: " * string(original_cost) * "\n Reconfigured Objective Value: " * string(original_cost - env.reward))

    return return_config

end




function parameter_sweep(path::String, bus::String, branch::String, policy, indices::Vector, widths::Vector, n_samples::Int)
    
    env = create_branch_env(path, bus, branch);

    original_cost = env.prev_cost

    action = policy(env)
    current_state = env.state
    println(action)
    function f(x, y) 
        env.state = [if i==indices[1] x elseif i==indices[2] y else current_state[i] end for i in range(1, length(current_state))]
        # env = create_branch_env(path, bus, branch)
        # policy.policy.explorer.step = 2
        # policy.policy.explorer.warmup_steps = 1
        # policy.policy.explorer.ϵ_stable = 0
        # policy.policy.explorer.ϵ_init = 0
        
        return policy(env) - 1
    end

    x_width = widths[1]
    y_width = widths[2]

    x_left = current_state[indices[1]] - x_width/2
    x_right = current_state[indices[1]] + x_width/2
    y_left = current_state[indices[2]] - y_width/2
    y_right = current_state[indices[2]] + y_width/2

    x = range(x_left, x_right, length=n_samples)
    y = range(y_left, y_right, length=n_samples)
    
    z = @. f(x', y)

    # pyplot()

    # display(contourf(x, y, z, levels=20, color=:turbo))
    # display(heatmap(x, y, z, colorbar_ticks=(0:3, 0:3)))
    heatmap(x, y, z)
    title!("Action Space vs. State Variation")
    xlabel!(L"x")
    ylabel!(L"y")

end


path = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case30_ieee.m")
env = create_branch_env(path);

# hook = TotalRewardPerEpisode()
# run(RandomPolicy(action_space(env)), env, StopAfterEpisode(25), hook)
# plot(hook.rewards)

seed=123
# LEARNER = "A2C"
LEARNER = "DQN"
UPDATE_FREQ = 200
N_ITERATIONS = 2000

rng = StableRNG(seed)
# env = CartPoleEnv(; T = Float32, rng = rng)
ns, na = length(state(env)), length(action_space(env))

agent = Agent(
    policy = QBasedPolicy(
        learner = BasicDQNLearner(
            approximator = NeuralNetworkApproximator(
                model = Chain(
                    Dense(ns, 128, relu; init = glorot_uniform(rng)),
                    Dense(128, 128, relu; init = glorot_uniform(rng)),
                    Dense(128, na; init = glorot_uniform(rng)),
                ) |> gpu,
                optimizer = ADAM(),
            ),
            batch_size = UPDATE_FREQ,
            min_replay_history = 100,
            loss_func = huber_loss,
            rng = rng,
        ),
        explorer = EpsilonGreedyExplorer(
            kind = :exp,
            ϵ_stable = 0.01,
            decay_steps = 500,
            rng = rng,
        ),
    ),
    trajectory = CircularArraySARTTrajectory(
        capacity = 1000,
        state = Vector{Float32} => (ns,),
    ),
)


# stop_condition = StopAfterStep(100, is_show_progress=true)
stop_condition = StopAfterEpisode(N_ITERATIONS)
hook = RewardsPerEpisode()
ex = Experiment(agent, env, stop_condition, hook, "# BasicDQN <-> PowerEnv")
run(ex)
# plot(ex.hook.rewards)
display(plot([sum(x) for x in ex.hook.rewards]))


agent.policy.explorer.step = 2
agent.policy.explorer.warmup_steps = 1
agent.policy.explorer.ϵ_stable = 0
agent.policy.explorer.ϵ_init = 0
test_path = joinpath(@__DIR__, "..\\ieee_data\\WB5.m")
run_inference(test_path, "4", "3", agent)
parameter_sweep(test_path, "4", "3", agent.policy, [18, 19], [50, 50], 50)

parameter_sweep(test_path, "4", "3", agent, [9, 13], [50, 50], 100)
parameter_sweep(test_path, "4", "3", agent, [22, 26], [80, 400], 100)
parameter_sweep(test_path, "4", "3", agent, [22, 27], [80, 400], 100)
parameter_sweep(test_path, "4", "3", agent, [22, 28], [80, 400], 100)