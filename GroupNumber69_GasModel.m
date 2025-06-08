% Read in the data and filter to required time period
all_data = readtable('gas_consumption_quantity_price.csv');
from_date = datetime(2023,08,04);
to_date = datetime(2023, 08, 05);
filt_data = all_data(all_data.Period_UTC >= from_date & all_data.Period_UTC < to_date, : );

% Visualise data
figure;
plot(filt_data.Period_UTC, filt_data.Quantity_kwh_);
xlabel("Time Period");
ylabel("Demand (kWh)");
title("Gas Demand Aug 4, 2023");
grid("on")
figure;
plot(filt_data.Period_UTC, filt_data.Price_p_kwhInclVAT_);
xlabel("Time Period");
ylabel("Price (p/kWh)");
title("Gas Cost Aug 4, 2023");
grid("on")

%Create optimisation problem
prob = optimproblem('ObjectiveSense', 'min');
x = optimvar('x', 48, 1, 'Type', 'continuous', 'LowerBound', 0, 'UpperBound', 4);

% Contraint on 4kWh max in 30 mins
for i = 1:48
    constraintName = sprintf('const%d', i);    
    expr = x(i) <= 1.7;    
    prob.Constraints.(constraintName) = expr;
end

% Calculate total demand
total_demand = sum(filt_data.Quantity_kwh_);

% Add constraint for total demand
prob.Constraints.total_demand_constraint = sum(x) >= total_demand;

% Define objective function
obj = sum(x.* filt_data.Price_p_kwhInclVAT_); 
prob.Objective = obj;
solution = solve(prob);
solution.x;

% Plot Results
figure;
yyaxis left
plot(filt_data.Period_UTC, filt_data.Quantity_kwh_);
xlabel("Time Period");
ylabel("Demand (kWh)");
title("Gas Demand Aug 4, 2023");
grid("on")
hold on;
yyaxis right
plot(filt_data.Period_UTC, solution.x)
ylabel("Optimal Demand (kWh)")

% Plot the Optimal Demand against cost
figure; 
yyaxis left
plot(filt_data.Period_UTC,filt_data.Price_p_kwhInclVAT_);
xlabel("Time Period");
ylabel("Cost (p/kWh)");
title("Gas-Cost");
grid("on")
hold on;
yyaxis right;
ylabel("Optimised demand (kWh)");
plot(filt_data.Period_UTC,solution.x);

% Quantify Savings (or lack of!)
before_cost = sum(filt_data.Quantity_kwh_ .* filt_data.Price_p_kwhInclVAT_)
after_cost = sum(solution.x .* filt_data.Price_p_kwhInclVAT_)
saving = before_cost - after_cost
epsilon = 9e-9;
if (saving <= epsilon)
    sprintf("No saving")
else 
    sprintf("Saving = %.2f pence", saving);
end
disp(ans)

