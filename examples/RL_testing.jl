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


includet("../src/NetworkFunctions.jl")
includet("../src/Configurations.jl")
includet("../src/ConfigurationRL.jl")
using ..NetworkFunctions
using ..Configurations
using ..ConfigurationRL


function create_env(path, bus_number)

    # Parse and solve original OPF problem instance.
    network_data = PowerModels.parse_file(path)
    result = solve_opf(network_data, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0))

    # Number of buses.
    n_buses = length(network_data["bus"])

    # Set environment's power network field to power network along with solved powerflow data.
    power_network = copy(network_data)
    update_data!(power_network, result["solution"])
    # println(power_network["gen"])
    # Set initial reward.
    reward = 0
    previous_cost = result["objective"]

    # All possible actions (binary configurations).
    adj_branches = get_adjacent_branches(power_network, bus_number)
    n_bits = 1 + 2*length(adj_branches)
    n_actions = 2^n_bits
    # action_space = Array(0:(n_actions-1))
    action_space = Base.OneTo(n_actions)

    # Generate size of state by generating fully connected config.
    fully_connected_config = make_configuration_template(power_network, bus_number; connected=1)
    config_network = apply_bus_configuration(power_network, fully_connected_config)
    config_result = solve_opf(config_network, ACPPowerModel, JuMP.optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>150, "print_level"=>0))
    update_data!(config_network, config_result["solution"])
    
    # Map state to state represented by current powerflow solution.
    state = network_to_state(power_network, bus_number, n_buses, config_network);
    # println(state)
    state_space = Space(fill(-Inf64..Inf64, length(state)))
    state_size = length(state)

    return PowerEnv(    action_space,
                        state_space,
                        0,
                        state,
                        reward,
                        n_actions,
                        power_network,
                        path,
                        bus_number,
                        false,
                        n_buses,
                        state_size,
                        config_network,
                        0,
                        previous_cost)
    

end


data_file = joinpath(@__DIR__, "..\\ieee_data\\WB5.m")
env = create_env(data_file, 3);

# hook = TotalRewardPerEpisode()
# run(RandomPolicy(action_space(env)), env, StopAfterEpisode(25), hook)
# plot(hook.rewards)

seed=123

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
            batch_size = 32,
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
# UPDATE_FREQ = 100
# agent = Agent(
#         policy = QBasedPolicy(
#             learner = A2CLearner(
#                 approximator = ActorCritic(
#                     actor = Chain(
#                         Dense(ns, 256, relu; init = glorot_uniform(rng)),
#                         Dense(256, na; init = glorot_uniform(rng)),
#                     ),
#                     critic = Chain(
#                         Dense(ns, 256, relu; init = glorot_uniform(rng)),
#                         Dense(256, 1; init = glorot_uniform(rng)),
#                     ),
#                     optimizer = ADAM(1e-3),
#                 ) |> cpu,
#                 γ = 0.99f0,
#                 actor_loss_weight = 1.0f0,
#                 critic_loss_weight = 0.5f0,
#                 entropy_loss_weight = 0.001f0,
#                 update_freq = UPDATE_FREQ,
#             ),
#             explorer = BatchExplorer(GumbelSoftmaxExplorer()),
#         ),
#         trajectory = CircularArraySARTTrajectory(;
#             capacity = UPDATE_FREQ,
#             state = Vector{Float32} => (ns, 1),
#             action = Vector{Int} => (1,),
#             reward = Vector{Float32} => (1, ),
#             terminal = Vector{Bool} => (1, ),
#         ),
#     )


# stop_condition = StopAfterStep(100, is_show_progress=true)
stop_condition = StopAfterEpisode(1000)
hook = RewardsPerEpisode()
ex = Experiment(agent, env, stop_condition, hook, "# BasicDQN <-> PowerEnv")
run(ex)
# plot(ex.hook.rewards)
plot([sum(x) for x in ex.hook.rewards])