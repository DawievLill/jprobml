#https://github.com/biaslab/ForneyLab.jl/blob/master/demo/2_state_estimation_forward_backward.ipynb
# Forward backward smoothing

# Data
Random.seed!(1)
n_samples = 20
x_data = [t for t=1:n_samples] # State
y_data = x_data + sqrt(200.0)*randn(n_samples); # Noisy observations of state

using ForneyLab

g = FactorGraph()

# Prior statistics
m_x_0 = placeholder(:m_x_0)
v_x_0 = placeholder(:v_x_0)

# State prior
@RV x_0 ~ GaussianMeanVariance(m_x_0, v_x_0)

# Transition and observation model
x = Vector{Variable}(undef, n_samples)
y = Vector{Variable}(undef, n_samples)

x_t = x_0
for t = 1:n_samples
    global x_t
    @RV n_t ~ GaussianMeanVariance(0.0, 200.0) # observation noise
    @RV x[t] = x_t + 1.0
    # Name variable for ease of lookup
    sym  = Symbol("x_", t)
    x[t].id = sym #:x_t;
    println(sym)
    @RV y[t] = x[t] + n_t

    # Data placeholder
    placeholder(y[t], :y, index=t)

    # Reset state for next step
    x_t = x[t]
end

println("generating inference code")
algo = Meta.parse(sumProductAlgorithm(x))
println("Compiling")
eval(algo) # Load algorithm

# Prepare data dictionary and prior statistics
data = Dict(:y     => y_data,
            :m_x_0 => 0.0,
            :v_x_0 => 1000.0)

# Execute algorithm
println("running forwards backwads")
marginals = step!(data);
# Extract posterior statistics
m_x = [mean(marginals[:x_*t]) for t = 1:n_samples]
v_x = [var(marginals[:x_*t]) for t = 1:n_samples]

using Plots; pyplot()

xs = 1:n_samples
scatter(xs, y_data, color=[:blue], label="y")
plot!(xs, x_data, color=[:black], label="x")
plot!(xs, m_x, color=[:red], label="estimated x")
#grid("on")
ys = m_x; l = sqrt.(v_x); u = sqrt.(v_x);
#fill_between(xs, y.-l, y.+_u, color="b", alpha=0.3)
plot!([ys ys], fillrange=[ys.-l ys.+u], fillalpha=0.3, c=:red)
xlabel!("t")
fname = "Figures/forney-kalman-smoother.png"
savefig(fname)
