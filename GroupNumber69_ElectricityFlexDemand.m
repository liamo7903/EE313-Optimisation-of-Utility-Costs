% Read in the data and filter to required time period
all_data = readtable('electricity_consumption_quantity_price.csv');
from_date = datetime(2023,08,04);
to_date = datetime(2023, 08, 05);
filt_data = all_data(all_data.Period_UTC >= from_date & all_data.Period_UTC < to_date, : );

%Visualise data
figure;
plot(filt_data.Period_UTC, filt_data.Quantity_kwh_);
xlabel("Time Period");
ylabel("Demand (kWh)");
title("Electricity Demand Aug 4, 2023");
grid("on")
figure;
plot(filt_data.Period_UTC, filt_data.Price_p_kwhInclVAT_);
xlabel("Time Period");
ylabel("Price");
title("Electricity Cost Aug 4, 2023");
grid("on")

% Create optimisation problem
prob = optimproblem('ObjectiveSense', 'min');
x = optimvar('x', 48, 1, 'Type', 'continuous', 'LowerBound', 0, 'UpperBound', 4);

% Contraint on 4kWh max in 30 mins
for i = 1:48
    constraintName = sprintf('const%d', i);   
    expr = x(i) <= 4;    
    prob.Constraints.(constraintName) = expr;
end

% Contraint on allowed += i% of original demand per time interval
dem_res = 0.5; % example 30 percent deviation from nominal allowed 

for j = 1 : 48
    
    lowerConstraintName = sprintf('lowerConst%d', j+48);
    upperConstraintName = sprintf('upperConst%d', j+1+48);
    
    % Set constraints for lower and upper bounds of each decision variable
    lowerExpr = (1-dem_res)*filt_data.Quantity_kwh_(j) <= x(j);
    upperExpr = x(j) <= (1+dem_res)*filt_data.Quantity_kwh_(j);
    prob.Constraints.(lowerConstraintName) = lowerExpr;
    prob.Constraints.(upperConstraintName) = upperExpr;
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

% Plot the new usage over time
figure;
yyaxis left;
plot(filt_data.Period_UTC, filt_data.Quantity_kwh_);
xlabel("Time Period");
ylabel("Demand (kWh)");
title("Electricity Demand Aug 4, 2023");
grid("on")
hold on;
plot(filt_data.Period_UTC, solution.x);
yyaxis right;
plot(filt_data.Period_UTC, filt_data.Price_p_kwhInclVAT_);
ylabel("Price (p/kWh)");
legendEntry1 = 'Electricity Demand (No Demand Response)';
legendEntry2 = sprintf('Electricity Demand (Demand response %.0f%%)', dem_res*100);
legendEntry3 = 'Electricity Cost';
legend(legendEntry1, legendEntry2, legendEntry3,'Location',"northwest");
set(legend, 'FontSize', 6);

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
disp(after_cost)
disp(ans)
