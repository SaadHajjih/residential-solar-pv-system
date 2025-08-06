% Parameters
days = 30;                          % Simulation duration (1 month)
hours_per_day = 24;
total_hours = days * hours_per_day;
% System Parameters
A4_daily_energy = 36;               % kWh/day (load)
C14_PV_power = 12000;               % W (increased PV power to 12 kW)
C3_daily_PV_energy = 42.35;         % kWh/day (PV production)
B8_battery_capacity = 1600;         % Ah (total battery capacity)
A2_battery_voltage = 48;            % V
B2_DoD = 0.9;                       % Depth of Discharge
A1_inverter_eff = 0.976;            % Inverter efficiency
C2_battery_eff = 0.85;              % Battery round-trip efficiency
grid_failure_start = 600;           % Hour index for May 26th (00:00)
grid_failure_duration = 24;         % 24-hour outage
% Convert battery capacity to kWh
battery_kWh_total = (B8_battery_capacity * A2_battery_voltage) / 1000;  % kWh
battery_kWh_usable = battery_kWh_total * B2_DoD;  % Usable energy
% Initialize arrays
load_hourly = zeros(total_hours, 1);       % kWh
pv_hourly = zeros(total_hours, 1);         % kWh
battery_SoC = zeros(total_hours+1, 1);     % State of Charge (kWh)
grid_import_export = zeros(total_hours, 1);% kWh (positive = import, negative = export)
dod = zeros(total_hours+1, 1);             % Depth of Discharge
% Time vector (May 2025)
start_date = datetime(2025, 5, 1);
time_vector = start_date + hours(0:total_hours-1)';  % Ensure column vector
% Simulate variable load (higher in evenings)
for h = 1:total_hours
    hour_of_day = mod(h-1, 24) + 1;
    if hour_of_day >= 6 && hour_of_day <= 10  % Morning
        load_hourly(h) = 0.5 * A4_daily_energy / hours_per_day;  % Low demand
    elseif hour_of_day > 10 && hour_of_day <= 18  % Daytime
        load_hourly(h) = 1.0 * A4_daily_energy / hours_per_day;  % Base demand
    else  % Evening/Night
        load_hourly(h) = 1.5 * A4_daily_energy / hours_per_day;  % High demand
    end
end
% Simulate PV generation (optimized profile)
peak_sun_hours = 5.891;
for h = 1:total_hours
    hour_of_day = mod(h-1, 24) + 1;
    if hour_of_day >= 6 && hour_of_day <= 18  % Daytime PV generation
        % Higher PV output with sharper midday peak
        pv_hourly(h) = C14_PV_power / 1000 * ...
            sin(pi * (hour_of_day - 6) / 12)^2 * (1 / peak_sun_hours);
    else
        pv_hourly(h) = 0;  % No PV at night
    end
end
% Initialize battery SoC
battery_SoC(1) = battery_kWh_usable;  % Start fully charged
% Main simulation loop
for h = 1:total_hours
    demand = load_hourly(h);
    pv = pv_hourly(h);
    if h >= grid_failure_start && h <= grid_failure_start + grid_failure_duration - 1
        grid_status = 0;  % Grid down
    else
        grid_status = 1;  % Grid up
    end
    net_energy = (pv * A1_inverter_eff) - demand;
    if grid_status == 0
        if net_energy >= 0
            battery_charge = net_energy * C2_battery_eff;
        else
            battery_charge = net_energy / C2_battery_eff;
        end
    else
        if net_energy > 0
            battery_energy_needed = (battery_kWh_usable - battery_SoC(h)) / C2_battery_eff;
            charge_energy = min(net_energy, battery_energy_needed);
            battery_charge = charge_energy * C2_battery_eff;
            grid_import_export(h) = -(net_energy - charge_energy);
        else
            grid_import_export(h) = abs(net_energy);
            battery_charge = 0;
        end
    end
    battery_SoC(h+1) = max(min(battery_SoC(h) + battery_charge, battery_kWh_usable), 0);
    dod(h+1) = (battery_kWh_total - battery_SoC(h+1)) / battery_kWh_total;
end
% Plot results
figure;
subplot(5,1,1);
plot(time_vector, load_hourly * 1000, 'b', 'DisplayName', 'Load (W)');
hold on;
plot(time_vector, pv_hourly * 1000, 'g', 'DisplayName', 'PV Generation (W)');
title('Load vs PV Generation');
xlabel('Time'); ylabel('Power (W)'); legend; grid on;
subplot(5,1,2);
plot(time_vector, battery_SoC(1:end-1), 'r', 'DisplayName', 'Battery SoC (kWh)');
title('Battery State of Charge');
xlabel('Time'); ylabel('Energy (kWh)'); legend; grid on;
xline(datetime(2025, 5, 26), 'r--', 'May 26th Outage', 'LabelVerticalAlignment', 'middle');
subplot(5,1,3);
plot(time_vector, dod(1:end-1), 'm', 'DisplayName', 'Battery DoD');
title('Battery Depth of Discharge (DoD)');
xlabel('Time'); ylabel('DoD'); legend; grid on;
ylim([0 1]);
yline(B2_DoD, 'k--', 'Allowable DoD Limit (90%)', 'LabelVerticalAlignment', 'middle');
subplot(5,1,4);
plot(time_vector, grid_import_export * 1000, 'k', 'DisplayName', 'Grid Import/Export (W)');
title('Grid Interaction');
xlabel('Time'); ylabel('Power (W)'); legend; grid on;
xline(datetime(2025, 5, 26), 'r--', 'May 26th Outage', 'LabelVerticalAlignment', 'middle');
subplot(5,1,5);
plot(time_vector, load_hourly * 1000, 'b', 'DisplayName', 'Load (W)');
hold on;
plot(time_vector, pv_hourly * 1000, 'g', 'DisplayName', 'PV Generation (W)');
plot(time_vector, grid_import_export * 1000, 'k--', 'DisplayName', 'Grid Interaction (W)');
title('Load vs  PV, battery and Grid Interaction ');
xlabel('Time'); ylabel('Power (W)'); legend; grid on;
xline(datetime(2025, 5, 26), 'r--', 'May 26th Outage', 'LabelVerticalAlignment', 'middle');

