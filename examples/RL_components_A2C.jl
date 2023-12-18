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
includet("../src/ComponentsRL.jl")
using ..NetworkFunctions
using ..Configurations
using ..ComponentsRL


function run_inference(path::String, bus::String, branch::String, policy)
    
    env = create_branch_env(path, bus, branch);

    action = policy(env)
    return_config = action_to_branch_configuration(branch, bus, action)

    # Step environment and solve/print objective value for configuration.
    env(action)
    println(env.reward)
    display(powerplot(env.network_manager.config));

    return return_config

end


path = joinpath(@__DIR__, "..\\ieee_data\\pglib_opf_case30_ieee.m")
env = create_branch_env(path);

# hook = TotalRewardPerEpisode()
# run(RandomPolicy(action_space(env)), env, StopAfterEpisode(25), hook)
# plot(hook.rewards)

seed=123
UPDATE_FREQ = 200
N_ITERATIONS = 2000

rng = StableRNG(seed)
# env = CartPoleEnv(; T = Float32, rng = rng)
ns, na = length(state(env)), length(action_space(env))

agent = Agent(
        policy = QBasedPolicy(
            learner = A2CLearner(
                approximator = ActorCritic(
                    actor = Chain(
                        Dense(ns, 128, relu; init = glorot_uniform(rng)),
                    Dense(128, 128, relu; init = glorot_uniform(rng)),
                    Dense(128, na; init = glorot_uniform(rng)),),
                    critic = Chain(
                        Dense(ns, 256, relu; init = glorot_uniform(rng)),
                        Dense(256, 1; init = glorot_uniform(rng))),
                    optimizer = ADAM(),
                ) |> gpu,
                γ = 0.99f0,
                actor_loss_weight = 1.0f0,
                critic_loss_weight = 0.5f0,
                entropy_loss_weight = 0.01f0,
                update_freq = UPDATE_FREQ,
            ),
            explorer = BatchExplorer(GumbelSoftmaxExplorer()),
        ),
        trajectory = CircularArraySARTTrajectory(;
            capacity = UPDATE_FREQ,
            state = Vector{Float32} => (ns, 1),
            action = Vector{Int} => (1,),
            reward = Vector{Float32} => (1, ),
            terminal = Vector{Bool} => (1, ),
        ),
    )


# stop_condition = StopAfterStep(100, is_show_progress=true)
stop_condition = StopAfterEpisode(N_ITERATIONS)
hook = RewardsPerEpisode()
ex = Experiment(agent, env, stop_condition, hook, "# BasicDQN <-> PowerEnv")
run(ex)
# plot(ex.hook.rewards)
plot([sum(x) for x in ex.hook.rewards])