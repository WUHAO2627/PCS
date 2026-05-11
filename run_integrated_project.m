clear; clc;

addpath('core_functions');
addpath('advanced_algorithms');
addpath('project/config');
addpath('project/controller');
addpath('project/integration');
addpath('simulation/integrated');

build_integrated_system_model();
run('simulation/integrated/run_integrated_project_demo.m');
