% The GUI window for performing dynamics (forward and inverse) analysis
%
% Author        : Jonathan EDEN
% Created       : 2016
% Description    :

%--------------------------------------------------------------------------
%% Constructor
%--------------------------------------------------------------------------
function varargout = dynamics_GUI(varargin)
    % DYNAMICS_GUI MATLAB code for dynamics_GUI.fig
    %      DYNAMICS_GUI, by itself, creates a new DYNAMICS_GUI or raises the existing
    %      singleton*.
    %
    %      H = DYNAMICS_GUI returns the handle to a new DYNAMICS_GUI or the handle to
    %      the existing singleton*.
    %
    %      DYNAMICS_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in DYNAMICS_GUI.M with the given input arguments.
    %
    %      DYNAMICS_GUI('Property','Value',...) creates a new DYNAMICS_GUI or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before dynamics_GUI_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to dynamics_GUI_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %
    % See also: GUIDE, GUIDATA, GUIHANDLES

    % Edit the above text to modify the response to help dynamics_GUI

    % Last Modified by GUIDE v2.5 25-Mar-2017 20:40:29

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @dynamics_GUI_OpeningFcn, ...
                       'gui_OutputFcn',  @dynamics_GUI_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
end

%--------------------------------------------------------------------------
%% GUI Setup Functions
%--------------------------------------------------------------------------
% --- Executes just before dynamics_GUI is made visible.
function dynamics_GUI_OpeningFcn(hObject, ~, handles, varargin)
    % This function has no output args, see OutputFcn.
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % varargin   command line arguments to dynamics_GUI (see VARARGIN)

    % Choose default command line output for dynamics_GUI
    handles.output = hObject;

    % Update handles structure
    guidata(hObject, handles);
    
    % Load the state
    loadState(handles);
    GUIOperations.CreateTabGroup(handles);
    % UIWAIT makes dynamics_GUI wait for user response (see UIRESUME)
    % uiwait(handles.figure1);
end

% --- Outputs from this function are returned to the command line.
function varargout = dynamics_GUI_OutputFcn(~, ~, handles)
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Get default command line output from handles structure
    varargout{1} = handles.output;
end

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, ~, handles) %#ok<DEFNU>
    % hObject    handle to figure1 (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hint: delete(hObject) closes the figure
    saveState(handles);
    delete(hObject);
end

%--------------------------------------------------------------------------
%% Menu Functions
%--------------------------------------------------------------------------
% --------------------------------------------------------------------
function FileMenu_Callback(~, ~, ~) %#ok<DEFNU>
    % hObject    handle to FileMenu (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
end

% --------------------------------------------------------------------
function OpenMenuItem_Callback(~, ~, ~) %#ok<DEFNU>
    % hObject    handle to OpenMenuItem (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    file = uigetfile('*.fig');
    if ~isequal(file, 0)
        open(file);
    end
end

% --------------------------------------------------------------------
function PrintMenuItem_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to PrintMenuItem (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    printdlg(handles.figure1)
end

% --------------------------------------------------------------------
function CloseMenuItem_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to CloseMenuItem (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    selection = questdlg(['Close ' get(handles.figure1,'Name') '?'],...
                         ['Close ' get(handles.figure1,'Name') '...'],...
                         'Yes','No','Yes');
    if strcmp(selection,'No')
        return;
    end

    delete(handles.figure1)
end

%--------------------------------------------------------------------------
%% Popups
%--------------------------------------------------------------------------
% --- Executes on selection change in popupmenu1.
% --- Executes on selection change in trajectory_popup.
function trajectory_popup_Callback(~, ~, ~) %#ok<DEFNU>
    % hObject    handle to trajectory_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns trajectory_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from trajectory_popup
    
end

function trajectory_popup_Update(~, ~, handles)
    contents = cellstr(get(handles.model_text,'String'));
    model_type = contents{1};
    if(getappdata(handles.figure1,'toggle'))
        model_config = DevModelConfig(model_type);
    else
        model_config = ModelConfig(model_type);
    end
    setappdata(handles.trajectory_popup,'model_config',model_config);
    % Determine the cable sets
    trajectories_str = model_config.getTrajectoriesList();    
    if(~isempty(trajectories_str))
        set(handles.trajectory_popup, 'Value', 1);   set(handles.trajectory_popup, 'String', trajectories_str);
    else
        set(handles.trajectory_popup, 'Value', 1);   set(handles.trajectory_popup, 'String', 'No trajectories are defined for this robot');
    end
end

% --- Executes during object creation, after setting all properties.
function trajectory_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to trajectory_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
end

% --- Executes on selection change in dynamics_popup.
function dynamics_popup_Callback(hObject, ~, handles) 
    % hObject    handle to dynamics_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns dynamics_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from dynamics_popup
    contents = cellstr(get(hObject,'String'));
    toggle_visibility(contents{get(hObject,'Value')},handles);
    solver_type_popup_update(handles.solver_type_popup,handles);
    % Maybe update the solver type
end


% --- Executes during object creation, after setting all properties.
function dynamics_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to dynamics_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    dynamics_str = {'Forward Dynamics','Inverse Dynamics'};
    set(hObject, 'String', dynamics_str);
end

% --- Executes on selection change in solver_class_popup.
function solver_class_popup_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to solver_class_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns solver_class_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from solver_class_popup
    % First update then apply callback
    % Updates
    solver_type_popup_update(handles.solver_type_popup,handles);
    objective_popup_Update(handles.objective_popup,handles);
    constraint_popup_Update(handles.constraint_popup,handles);
    tuning_parameter_popup_Update(handles.tuning_parameter_popup,handles);
    % Callbacks
    objective_popup_Callback(handles.objective_popup,[],handles);
    constraint_popup_Callback(handles.constraint_popup,[],handles);
    tuning_parameter_popup_Callback(handles.tuning_parameter_popup,[],handles);
end

% --- Executes during object creation, after setting all properties.
function solver_class_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to solver_class_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    settingsXMLObj = GUIOperations.GetSettings('/GUI/XML/dynamicsXML.xml');
    setappdata(hObject,'settings',settingsXMLObj);
    solver_str = GUIOperations.XmlObj2StringCellArray(settingsXMLObj.getElementsByTagName('simulator').item(0).getElementsByTagName('solver_class'),'id');
    set(hObject, 'String', solver_str);
end

% --- Executes on selection change in objective_popup.
function objective_popup_Callback(hObject, ~, handles) 
    % hObject    handle to objective_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns objective_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from objective_popup
    contents = cellstr(get(handles.solver_class_popup,'String'));
    solver_class_id = contents{get(handles.solver_class_popup,'Value')};
    settings = getappdata(handles.solver_class_popup,'settings');
    solverObj = settings.getElementById(solver_class_id);
    objectivesUnfiltered = solverObj.getElementsByTagName('objectives').item(0);
    if(~isempty(objectivesUnfiltered))
        objectivesObj = objectivesUnfiltered.getElementsByTagName('objective');
        objectiveNumber = get(hObject,'Value');
        objective = objectivesObj.item(objectiveNumber-1);
        modObj = getappdata(handles.cable_text,'modObj');
        weight_number = get_weight_number(objective,modObj);
        objective_table_Update(weight_number,handles.objective_table);
    end
end

function objective_popup_Update(hObject,handles)
    contents = cellstr(get(handles.solver_class_popup,'String'));
    solver_class_id = contents{get(handles.solver_class_popup,'Value')};
    settings = getappdata(handles.solver_class_popup,'settings');
    solverObj = settings.getElementById(solver_class_id);
    objectivesUnfiltered = solverObj.getElementsByTagName('objectives').item(0);
    if(isempty(objectivesUnfiltered))
        set(hObject,'Value',1);
        set(hObject,'String',{' '});
        set(hObject,'Visible','off');
        set(handles.objective_text,'Visible','off');
        set(handles.objective_radio,'Visible','off');
        set(handles.objective_table,'Visible','off');
    else
        set(hObject,'Visible','on');
        set(handles.objective_text,'Visible','on');
        set(handles.objective_radio,'Visible','on');
        set(handles.objective_table,'Visible','on');
        objective_str = GUIOperations.XmlObj2StringCellArray(objectivesUnfiltered.getElementsByTagName('objective'),'type');
        set(hObject,'Value',1);
        set(hObject, 'String', objective_str);
    end
end

% --- Executes during object creation, after setting all properties.
function objective_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to objective_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes on selection change in solver_type_popup.
function solver_type_popup_Callback(~, ~, ~) %#ok<DEFNU>
    % hObject    handle to solver_type_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns solver_type_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from solver_type_popup
end

function solver_type_popup_update(hObject,handles)
    % Determine whether forward or inverse dynamics
    contents = cellstr(get(handles.dynamics_popup,'String'));
    dynamics_id = contents{get(handles.dynamics_popup,'Value')};
    if(strcmp(dynamics_id,'Forward Dynamics'))
        % Populate through the enum list
        e_list = enumeration(char('FDSolverType'));
        e_n         =   length(e_list);
        e_list_str  =   cell(1,e_n);
        for i=1:e_n
            temp_str = char(e_list(i));
            e_list_str{i} = temp_str(1:length(temp_str));
        end
        set(hObject,'Value',1);    set(hObject, 'String', e_list_str);
    else
        contents = cellstr(get(handles.solver_class_popup,'String'));
        solver_class_id = contents{get(handles.solver_class_popup,'Value')};
        settings = getappdata(handles.solver_class_popup,'settings');
        solverObj = settings.getElementById(solver_class_id);
        enum_file = solverObj.getElementsByTagName('solver_type_enum').item(0).getFirstChild.getData;
        e_list = enumeration(char(enum_file));
        e_n         =   length(e_list);
        e_list_str  =   cell(1,e_n);
        for i=1:e_n
            temp_str = char(e_list(i));
            e_list_str{i} = temp_str(1:length(temp_str));
        end
        set(hObject,'Value',1);    set(hObject, 'String', e_list_str);
    end
end

% --- Executes during object creation, after setting all properties.
function solver_type_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to solver_type_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes on selection change in plot_type_popup.
function plot_type_popup_Callback(hObject, ~, ~) 
    % hObject    handle to plot_type_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns plot_type_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from plot_type_popup
    settingsXMLObj = GUIOperations.GetSettings('/GUI/XML/dynamicsXML.xml');
    plotsObj = settingsXMLObj.getElementsByTagName('simulator').item(0).getElementsByTagName('plot_functions').item(0).getElementsByTagName('plot_function');
    contents = get(hObject,'Value');
    plotObj = plotsObj.item(contents-1);
    setappdata(hObject,'num_plots',plotObj.getElementsByTagName('figure_quantity').item(0).getFirstChild.getData);
end

% --- Executes during object creation, after setting all properties.
function plot_type_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to plot_type_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    settingsXMLObj = GUIOperations.GetSettings('/GUI/XML/dynamicsXML.xml');
    plot_str = GUIOperations.XmlObj2StringCellArray(settingsXMLObj.getElementsByTagName('simulator').item(0).getElementsByTagName('plot_functions').item(0).getElementsByTagName('plot_function'),'type');
    set(hObject,'Value',1);    set(hObject, 'String', plot_str);
    setappdata(hObject,'num_plots',1);
end

% --- Executes on selection change in constraint_popup.
function constraint_popup_Callback(hObject, ~, handles) 
    % hObject    handle to constraint_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns constraint_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from constraint_popup
    if(get(hObject,'Value') ~= 1)
        contents = cellstr(get(handles.solver_class_popup,'String'));
        solver_class_id = contents{get(handles.solver_class_popup,'Value')};
        settings = getappdata(handles.solver_class_popup,'settings');
        solverObj = settings.getElementById(solver_class_id);
        constraintsUnfiltered = solverObj.getElementsByTagName('constraints').item(0);
        if(~isempty(constraintsUnfiltered))
            constraintsObj = constraintsUnfiltered.getElementsByTagName('constraint');
            constraintNumber = get(hObject,'Value');
            constraint = constraintsObj.item(constraintNumber-2);
            modObj = getappdata(handles.cable_text,'modObj');
            weight_number = get_weight_number(constraint,modObj);
            num_constraints = str2double(get(handles.constraint_number_edit,'String'));
            if(isnan(num_constraints))
                num_constraints = 1;
            end
            constraint_table_Update([num_constraints,weight_number],handles.constraint_table);
        end
    end
end

function constraint_popup_Update(hObject,handles)
    contents = cellstr(get(handles.solver_class_popup,'String'));
    solver_class_id = contents{get(handles.solver_class_popup,'Value')};
    settings = getappdata(handles.solver_class_popup,'settings');
    solverObj = settings.getElementById(solver_class_id);
    constraintsUnfiltered = solverObj.getElementsByTagName('constraints').item(0);
    if(isempty(constraintsUnfiltered))
        set(hObject,'Value',1);
        set(hObject,'String',{' '});
        set(hObject,'Visible','off');
        set(handles.constraint_text,'Visible','off');
        set(handles.constraint_table,'Visible','off');
        set(handles.constraint_number_edit,'Visible','off');
    else
        set(hObject,'Visible','on');
        set(handles.constraint_text,'Visible','on');
        set(handles.constraint_table,'Visible','on');
        set(handles.constraint_number_edit,'Visible','on');
        constraint_str = GUIOperations.XmlObj2StringCellArray(constraintsUnfiltered.getElementsByTagName('constraint'),'type');
        constraint_str = [{' '},constraint_str];
        set(hObject,'Value',1);
        set(hObject, 'String', constraint_str);
    end
end

% --- Executes during object creation, after setting all properties.
function constraint_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to constraint_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end 

% --- Executes on selection change in tuning_parameter_popup.
function tuning_parameter_popup_Callback(hObject, ~, handles) 
    % hObject    handle to objective_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns objective_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from objective_popup
    contents = cellstr(get(handles.solver_class_popup,'String'));
    solver_class_id = contents{get(handles.solver_class_popup,'Value')};
    settings = getappdata(handles.solver_class_popup,'settings');
    solverObj = settings.getElementById(solver_class_id);
    tuningUnfiltered = solverObj.getElementsByTagName('tuning_parameters').item(0);
    if(~isempty(tuningUnfiltered))
        tuningObj = tuningUnfiltered.getElementsByTagName('tuning_parameter');
        tuningNumber = get(hObject,'Value');
        tuning = tuningObj.item(tuningNumber-1);
        modObj = getappdata(handles.cable_text,'modObj');
        weight_number = get_weight_number(tuning,modObj);
        tuning_parameter_table_Update(weight_number,handles.tuning_parameter_table);
    end
end

function tuning_parameter_popup_Update(hObject,handles)
    contents = cellstr(get(handles.solver_class_popup,'String'));
    solver_class_id = contents{get(handles.solver_class_popup,'Value')};
    settings = getappdata(handles.solver_class_popup,'settings');
    solverObj = settings.getElementById(solver_class_id);
    tuningUnfiltered = solverObj.getElementsByTagName('tuning_parameters').item(0);
    if(isempty(tuningUnfiltered))
        set(hObject,'Value',1); set(hObject,'String',{' '});
        set(hObject,'Visible','off');
        set(handles.tuning_parameter_text,'Visible','off');
        set(handles.tuning_parameter_radio,'Visible','off');
        set(handles.tuning_parameter_table,'Visible','off');
    else
        set(hObject,'Visible','on');
        set(handles.tuning_parameter_text,'Visible','on');
        set(handles.tuning_parameter_radio,'Visible','on');
        set(handles.tuning_parameter_table,'Visible','on');
        objective_str = GUIOperations.XmlObj2StringCellArray(tuningUnfiltered.getElementsByTagName('tuning_parameter'),'type');
        set(hObject,'Value',1); set(hObject, 'String', objective_str);
    end
end

% --- Executes during object creation, after setting all properties.
function tuning_parameter_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to tuning_parameter_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

%--------------------------------------------------------------------------
%% Push Buttons
%--------------------------------------------------------------------------
% --- Executes on button press in run_button.
function run_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to run_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % First read the trajecory information
    clc; 
    contents = cellstr(get(handles.trajectory_popup,'String'));
    trajectory_id = contents{get(handles.trajectory_popup,'Value')};
    
    % Then read the form of dynamics
    contents = cellstr(get(handles.dynamics_popup,'String'));
    dynamics_id = contents{get(handles.dynamics_popup,'Value')};
    modObj = getappdata(handles.cable_text,'modObj');
    if(strcmp(dynamics_id,'Inverse Dynamics'))
        run_inverse_dynamics(handles,modObj,trajectory_id);
    else
        run_forward_dynamics(handles,modObj,trajectory_id);
    end
end

% --- Executes on button press in save_button.
function save_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to save_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    file_name = [CASPR_configuration.LoadHomePath(),'/GUI/config/*.mat'];
    [file,path] = uiputfile(file_name,'Save file name');
    saveState(handles,[path,file]);
end

% --- Executes on button press in load_button.
function load_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to load_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    path_string = CASPR_configuration.LoadHomePath();
    file_name = [path_string,'/GUI/config/*.mat'];
    settings = uigetfile(file_name);
    load(settings);
    mp_text = get(handles.model_text,'String');
    cs_text = get(handles.cable_text,'String');
    if(strcmp(state.simulator,'dynamics'))
        if(strcmp(mp_text,state.model_text)&&strcmp(cs_text,state.cable_text))
            set(handles.trajectory_popup,'value',state.trajectory_popup);
            set(handles.dynamics_popup,'value',state.dynamics_popup);
            set(handles.solver_class_popup,'value',state.solver_class_popup);
            solver_type_popup_update(handles.solver_type_popup,handles);
            dynamics_popup_Callback(handles.dynamics_popup, [], handles);
            set(handles.solver_type_popup,'value',state.solver_type_popup);
            set(handles.objective_popup,'value',state.objective_popup);
            set(handles.constraint_popup,'value',state.constraint_popup);
            set(handles.tuning_parameter_popup,'value',state.tuning_parameter_popup);
            set(handles.plot_type_popup,'value',state.plot_type_popup);
            set(handles.objective_table,'Data',state.objective_table);
            set(handles.constraint_table,'Data',state.constraint_table);
            set(handles.tuning_parameter_table,'Data',state.tuning_parameter_table);
            % Callback
            plot_type_popup_Callback(handles.plot_type_popup,[],handles);
            objective_popup_Callback(handles.objective_popup,[],handles);
            constraint_popup_Callback(handles.constraint_popup,[],handles);
            tuning_parameter_popup_Callback(handles.tuning_parameter_popup, [], handles);
        else
            warning('Incorrect Model Type'); %#ok<WNTAG>
        end
    else
        warning('File is not the correct file type'); %#ok<WNTAG>
    end
end


% --- Executes on button press in plot_button.
function plot_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to plot_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)  
    sim = getappdata(handles.figure1,'sim');
    if(isempty(sim))
        warning('No simulator has been generated. Please press run first'); %#ok<WNTAG>
    else
        contents = cellstr(get(handles.plot_type_popup,'String'));
        plot_type = contents{get(handles.plot_type_popup,'Value')};
        GUIOperations.GUIPlot(plot_type,sim,handles,str2double(getappdata(handles.plot_type_popup,'num_plots')),get(handles.undock_box,'value'));
    end
end

% --- Executes on button press in update_button.
function update_button_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to update_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    trajectory_popup_Update(hObject, eventdata, handles);
end

% --- Executes on button press in plot_movie_button.
function plot_movie_button_Callback(~, ~, handles) %#ok<DEFNU>
% hObject    handle to plot_movie_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Things that this should do
    sim = getappdata(handles.figure1,'sim');
    if(isempty(sim))
        warning('No simulator has been generated. Please press run first'); %#ok<WNTAG>
    else
        path_string = CASPR_configuration.LoadHomePath();
        % Check if the log folder exists
        if((exist([path_string,'/data'],'dir')~=7)||(exist([path_string,'/data/videos'],'dir')~=7))
            if((exist([path_string,'/data'],'dir')~=7))
                mkdir([path_string,'/data']);
            end
            mkdir([path_string,'/data/videos']);
        end      
        model_config = getappdata(handles.trajectory_popup,'model_config');
        file_name = [path_string,'/data/videos/dynamics_gui_output.avi'];
        [file,path] = uiputfile(file_name,'Save file name');
        sim.plotMovie(model_config.displayRange, model_config.viewAngle, [path,file], sim.timeVector(length(sim.timeVector)), 700, 700);
    end
end

%--------------------------------------------------------------------------
%% Toolbar buttons
%--------------------------------------------------------------------------
% --------------------------------------------------------------------
function save_figure_tool_ClickedCallback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to save_figure_tool (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    tabgp = getappdata(handles.figure1,'tabgp');
    s_tab = get(tabgp,'SelectedTab');
    ax = get(s_tab,'Children');
    f1 = figure; % Open a new figure with handle f1
    copyobj(ax,f1); % Copy axes object h into figure f1
    set(gca,'ActivePositionProperty','outerposition')
    set(gca,'Units','normalized')
    set(gca,'OuterPosition',[0 0 1 1])
    set(gca,'position',[0.1300 0.1100 0.7750 0.8150])
    [file,path] = uiputfile({'*.fig';'*.bmp';'*.eps';'*.emf';'*.jpg';'*.pcx';...
        '*.pbm';'*.pdf';'*.pgm';'*.png';'*.ppm';'*.svg';'*.tif'},'Save file name');
    if(path ~= 0)
        saveas(gcf,[path,file]);
    end
    close(f1);
end

% --------------------------------------------------------------------
function undock_figure_tool_ClickedCallback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to undock_figure_tool (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    tabgp = getappdata(handles.figure1,'tabgp');
    s_tab = get(tabgp,'SelectedTab');
    ax = get(s_tab,'Children');
    f1 = figure; % Open a new figure with handle f1
    copyobj(ax,f1); % Copy axes object h into figure f1
    set(gca,'ActivePositionProperty','outerposition')
    set(gca,'Units','normalized')
    set(gca,'OuterPosition',[0 0 1 1])
    set(gca,'position',[0.1300 0.1100 0.7750 0.8150])
end

% --------------------------------------------------------------------
function delete_figure_tool_ClickedCallback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to delete_figure_tool (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    tabgp = getappdata(handles.figure1,'tabgp');
    s_tab = get(tabgp,'SelectedTab');
    if(strcmp('0',get(s_tab,'Title')))
        % Do nothing
    else
        delete(s_tab);
    end
end


%--------------------------------------------------------------------------
%% Radio Buttons
%--------------------------------------------------------------------------
% --- Executes on button press in objective_radio.
function objective_radio_Callback(hObject, ~, handles) %#ok<DEFNU>
    % hObject    handle to objective_radio (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hint: get(hObject,'Value') returns toggle state of objective_radio
    r_value = get(hObject,'Value');
    Q_editable = get(handles.objective_table,'ColumnEditable');
    Q_n = size(Q_editable,2);
    if(r_value)
        set(handles.objective_table,'Data',ones(1,Q_n));
        set(handles.objective_table,'ColumnEditable',false(1,Q_n));
    else
        
        set(handles.objective_table,'ColumnEditable',true(1,Q_n));
    end
end

% --- Executes on button press in tuning_parameter_radio.
function tuning_parameter_radio_Callback(hObject,~, handles) %#ok<DEFNU>
    % hObject    handle to tuning_parameter_radio (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hint: get(hObject,'Value') returns toggle state of tuning_parameter_radio
    r_value = get(hObject,'Value');
    Q_editable = get(handles.tuning_parameter_table,'ColumnEditable');
    Q_n = size(Q_editable,2);
    if(r_value)
        set(handles.tuning_parameter_table,'Data',ones(1,Q_n));
        set(handles.tuning_parameter_table,'ColumnEditable',false(1,Q_n));
    else
        set(handles.tuning_parameter_table,'ColumnEditable',true(1,Q_n));
    end
end

%--------------------------------------------------------------------------
%% Toggle Buttons
%--------------------------------------------------------------------------
% --- Executes on button press in undock_box.
function undock_box_Callback(~, ~, ~) %#ok<DEFNU>
    % hObject    handle to undock_box (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hint: get(hObject,'Value') returns toggle state of undock_box
end

%--------------------------------------------------------------------------
%% Textboxes
%--------------------------------------------------------------------------
function constraint_number_edit_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to constraint_number_edit (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: get(hObject,'String') returns contents of constraint_number_edit as text
    %        str2double(get(hObject,'String')) returns contents of constraint_number_edit as a double
    constraint_popup_Callback(handles.constraint_popup,[],handles);
end

% --- Executes during object creation, after setting all properties.
function constraint_number_edit_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to constraint_number_edit (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

%--------------------------------------------------------------------------
%% Tables
%--------------------------------------------------------------------------
function objective_table_Update(dimension,hObject)
    set(hObject,'Data',ones(1,dimension));
    set(hObject,'ColumnWidth',{30});
    set(hObject,'ColumnEditable',true(1,dimension));
    q_position = get(hObject,'Position');
    if(dimension>4)
        q_position(2) = 0.35;
        q_position(4) = 0.19;
        set(hObject,'Position',q_position);
    else
        q_position(2) = 0.35;
        q_position(4) = 0.15;
        set(hObject,'Position',q_position);
    end
end

function constraint_table_Update(dimension,hObject)
    set(hObject,'Data',ones(dimension));
    set(hObject,'ColumnWidth',{30});
    set(hObject,'ColumnEditable',true(1,dimension(2)));
    q_position = get(hObject,'Position');
    if(dimension(2)>4)
        q_position(2) = 0.04;
        q_position(4) = 0.19;
        set(hObject,'Position',q_position);
    else
        q_position(2) = 0.04;
        q_position(4) = 0.15;
        set(hObject,'Position',q_position);
    end
end

function tuning_parameter_table_Update(dimension,hObject)
    set(hObject,'Data',ones(1,dimension));
    set(hObject,'ColumnWidth',{30});
    set(hObject,'ColumnEditable',true(1,dimension));
    q_position = get(hObject,'Position');
    if(dimension>4)
        q_position(2) = 0.35;
        q_position(4) = 0.19;
        set(hObject,'Position',q_position);
    else
        q_position(2) = 0.35;
        q_position(4) = 0.15;
        set(hObject,'Position',q_position);
    end
end

%--------------------------------------------------------------------------
% Additional Functions
%--------------------------------------------------------------------------
function run_inverse_dynamics(handles,modObj,trajectory_id)
    % Determine the solver
    id_solver = load_idsolver(handles,modObj);
    % Read the type of plot
    contents = cellstr(get(handles.plot_type_popup,'String'));
    plot_type = contents{get(handles.plot_type_popup,'Value')};
        
    % Setup the inverse dynamics simulator with the SystemModel
    % object and the inverse dynamics solver
    disp('Start Setup Simulation');
    set(handles.status_text,'String','Setting up simulation');
    drawnow;
    start_tic = tic;
    idsim = InverseDynamicsSimulator(modObj, id_solver);
    model_config = getappdata(handles.trajectory_popup,'model_config');
    trajectory= model_config.getTrajectory(trajectory_id);
    time_elapsed = toc(start_tic);
    fprintf('End Setup Simulation : %f seconds\n', time_elapsed);

    % Run the solver on the desired trajectory
    disp('Start Running Simulation');
    set(handles.status_text,'String','Simulation running');
    drawnow;
    start_tic = tic;
    idsim.run(trajectory);
    time_elapsed = toc(start_tic);
    fprintf('End Running Simulation : %f seconds\n', time_elapsed);

    % Display information from the inverse dynamics simulator
    fprintf('Optimisation computational time, mean : %f seconds, std dev : %f seconds, total: %f seconds\n', mean(idsim.compTime), std(idsim.compTime), sum(idsim.compTime));

    % Plot the data
    disp('Start Plotting Simulation');
    set(handles.status_text,'String','Simulation plotting');
    drawnow;
    start_tic = tic;
    GUIOperations.GUIPlot(plot_type,idsim,handles,str2double(getappdata(handles.plot_type_popup,'num_plots')),get(handles.undock_box,'Value'));
    time_elapsed = toc(start_tic);
    fprintf('End Plotting Simulation : %f seconds\n', time_elapsed);
    set(handles.status_text,'String','No simulation running');
    setappdata(handles.figure1,'sim',idsim);
    assignin('base','inverse_dynamics_simulator',idsim);
end

function id_solver = load_idsolver(handles,modObj)
    solver_class_contents = cellstr(get(handles.solver_class_popup,'String'));
    solver_class = solver_class_contents{get(handles.solver_class_popup,'Value')};
    solver_type_contents = cellstr(get(handles.solver_type_popup,'String'));
    solver_type = solver_type_contents{get(handles.solver_type_popup,'Value')};
    objective_contents = cellstr(get(handles.objective_popup,'String'));
    objective = objective_contents{get(handles.objective_popup,'Value')};
    empty_objective = strcmp(objective,' ');
    constraint_contents = cellstr(get(handles.constraint_popup,'String'));
    constraint = constraint_contents{get(handles.constraint_popup,'Value')};
    empty_constraint = strcmp(constraint,' ');
    tuning_parameter_contents = cellstr(get(handles.tuning_parameter_popup,'String'));
    tuning_parameter = tuning_parameter_contents{get(handles.tuning_parameter_popup,'Value')};
    empty_tuning_parameter = strcmp(tuning_parameter,' ');
    settings = getappdata(handles.solver_class_popup,'settings');
    if(empty_objective&&empty_constraint&&empty_tuning_parameter)
        % No inputs
        solver_function = str2func(solver_class);
        solverObj = settings.getElementById(solver_class);
        enum_file = solverObj.getElementsByTagName('solver_type_enum').item(0).getFirstChild.getData;
        id_solver = solver_function(modObj,eval([char(enum_file),'.',char(solver_type)]));
    elseif(empty_constraint&&empty_objective)
        % Only have tuning parameters
        solver_function = str2func(solver_class);
        solverObj = settings.getElementById(solver_class);
        enum_file = solverObj.getElementsByTagName('solver_type_enum').item(0).getFirstChild.getData;
        q_data = get(handles.tuning_parameter_table,'Data');
        id_solver = solver_function(modObj,q_data,eval([char(enum_file),'.',char(solver_type)]));
    elseif(empty_constraint)
        % Optimisation without constraints
        objective_function = str2func(objective);
        q_data = get(handles.objective_table,'Data');
        id_objective = objective_function(q_data');
        solver_function = str2func(solver_class);
        solverObj = settings.getElementById(solver_class);
        enum_file = solverObj.getElementsByTagName('solver_type_enum').item(0).getFirstChild.getData;
        id_solver = solver_function(modObj,id_objective,eval([char(enum_file),'.',char(solver_type)]));
    else
        % There are both constraints and objectives
        objective_function = str2func(objective);
        q_data = get(handles.objective_table,'Data');
        id_objective = objective_function(q_data');
        solver_function = str2func(solver_class);
        solverObj = settings.getElementById(solver_class);
        enum_file = solverObj.getElementsByTagName('solver_type_enum').item(0).getFirstChild.getData;
        id_solver = solver_function(modObj,id_objective,eval([char(enum_file),'.',char(solver_type)]));
        % Obtain the constaints
        constraint_function = str2func(constraint);
        q_data = get(handles.constraint_table,'Data');
        contents = cellstr(get(handles.solver_class_popup,'String'));
        solver_class_id = contents{get(handles.solver_class_popup,'Value')};
        settings = getappdata(handles.solver_class_popup,'settings');
        solverObj = settings.getElementById(solver_class_id);
        constraintUnfiltered = solverObj.getElementsByTagName('constraints').item(0);
        constraintObj = constraintUnfiltered.getElementsByTagName('constraint');
        constraintNumber = get(handles.constraint_popup,'Value');
        constraint = constraintObj.item(constraintNumber-2);
        weight_constants = str2num(constraint.getElementsByTagName('weight_constants').item(0).getFirstChild.getData); %#ok<ST2NM>
        for i = 1:size(q_data,1)
            id_solver.addConstraint(constraint_function(i, q_data(i,1:weight_constants(1))',...
                q_data(i,weight_constants(1)+1:weight_constants(1)+weight_constants(2)), ...
                q_data(i,weight_constants(1)+weight_constants(2)+1:weight_constants(1)+weight_constants(2)+weight_constants(3))));
        end
    end
end

function loadState(handles)
    % load all of the settings and initialise the values to match
    path_string = CASPR_configuration.LoadHomePath();
    file_name = [path_string,'/GUI/config/caspr_gui_state.mat'];
    set(handles.status_text,'String','No simulation running');
    if(exist(file_name,'file'))
        load(file_name);
        set(handles.model_text,'String',state.model_text);
        set(handles.cable_text,'String',state.cable_text);
        setappdata(handles.figure1,'toggle',state.checkbox_value);
        % This is to ensure that we are starting fresh
        state.modObj.bodyModel.occupied.reset();
        setappdata(handles.cable_text,'modObj',state.modObj);
        trajectory_popup_Update([], [], handles);
        file_name = [path_string,'/GUI/config/dynamics_gui_state.mat'];
        if(exist(file_name,'file'))
            load(file_name);
            mp_text = get(handles.model_text,'String');
            cs_text = get(handles.cable_text,'String');
            if(strcmp(mp_text,state.model_text)&&strcmp(cs_text,state.cable_text))
                set(handles.trajectory_popup,'value',state.trajectory_popup);
                set(handles.dynamics_popup,'value',state.dynamics_popup);
                set(handles.solver_class_popup,'value',state.solver_class_popup);
                solver_type_popup_update(handles.solver_type_popup,handles);
                dynamics_popup_Callback(handles.dynamics_popup, [], handles);
                set(handles.solver_type_popup,'value',state.solver_type_popup);
                set(handles.objective_popup,'value',state.objective_popup);
                set(handles.constraint_popup,'value',state.constraint_popup);
                set(handles.tuning_parameter_popup,'value',state.tuning_parameter_popup);
                set(handles.plot_type_popup,'value',state.plot_type_popup);
                set(handles.objective_table,'Data',state.objective_table);
                set(handles.constraint_table,'Data',state.constraint_table);
                set(handles.tuning_parameter_table,'Data',state.tuning_parameter_table);
                % Callback
                plot_type_popup_Callback(handles.plot_type_popup,[],handles);
                objective_popup_Callback(handles.objective_popup,[],handles);
                constraint_popup_Callback(handles.constraint_popup,[],handles);
                tuning_parameter_popup_Callback(handles.tuning_parameter_popup, [], handles);
            else
                initialise_popups(handles);
            end
        else
            initialise_popups(handles);
        end
    end
end

function saveState(handles,file_path)
    % Save all of the settings
    state.simulator                         =   'dynamics';
    % Texts
    state.model_text                        =   get(handles.model_text,'String');
    state.cable_text                        =   get(handles.cable_text,'String');
    % Popups
    state.trajectory_popup                  =   get(handles.trajectory_popup,'value');
    state.dynamics_popup                    =   get(handles.dynamics_popup,'value');
    state.solver_class_popup                =   get(handles.solver_class_popup,'value');
    state.solver_type_popup                 =   get(handles.solver_type_popup,'value');
    state.objective_popup                   =   get(handles.objective_popup,'value');
    state.constraint_popup                  =   get(handles.constraint_popup,'value');
    state.plot_type_popup                   =   get(handles.plot_type_popup,'value');
    state.tuning_parameter_popup            =   get(handles.tuning_parameter_popup,'value');
    % Tables
    state.objective_table                   =   get(handles.objective_table,'Data');
    state.constraint_table                  =   get(handles.constraint_table,'Data');
    state.tuning_parameter_table            =   get(handles.tuning_parameter_table,'Data');
    if(nargin>1)
        save(file_path,'state');
    else
        save([CASPR_configuration.LoadHomePath(),'/GUI/config/dynamics_gui_state.mat'],'state')
    end
end

function run_forward_dynamics(handles,modObj,trajectory_id)
    % This will be added once script_FD has been fixed
    % First read the solver form from the GUI
    id_objective = IDObjectiveMinQuadCableForce(ones(modObj.numActuatorsActive,1));
    id_solver = IDSolverQuadProg(modObj,id_objective, ID_QP_SolverType.MATLAB);
        
    % Setup the inverse dynamics simulator with the SystemModel
    % object and the inverse dynamics solver
    disp('Start Setup Simulation');
    set(handles.status_text,'String','Setting up simulation');
    drawnow;
    start_tic = tic;
    idsim = InverseDynamicsSimulator(modObj, id_solver);
    contents = cellstr(get(handles.solver_type_popup,'String'));
    solver_type = contents{get(handles.solver_type_popup,'Value')};
    fdsim = ForwardDynamicsSimulator(modObj,eval(['FDSolverType.',solver_type]));
    model_config = getappdata(handles.trajectory_popup,'model_config');
    trajectory= model_config.getTrajectory(trajectory_id);
    time_elapsed = toc(start_tic);
    fprintf('End Setup Simulation : %f seconds\n', time_elapsed);
    
    % First run the inverse dynamics
    disp('Start Running Inverse Dynamics Simulation');
    
    start_tic = tic;
    idsim.run(trajectory);
    time_elapsed = toc(start_tic);
    fprintf('End Running Inverse Dynamics Simulation : %f seconds\n', time_elapsed);
    set(handles.status_text,'String','Running inverse dynamics');
    drawnow;
    % Then run the forward dynamics
    disp('Start Running Forward Dynamics Simulation');
    set(handles.status_text,'String','Running forward dynamics');
    drawnow;
    start_tic = tic;
    fdsim.run(idsim.cableForcesActive, idsim.cableIndicesActive, trajectory.timeVector, trajectory.q{1}, trajectory.q_dot{1});
    time_elapsed = toc(start_tic);
    fprintf('End Running Forward Dynamics Simulation : %f seconds\n', time_elapsed);
    
    % Finally compare the results
    set(handles.status_text,'String','Plotting results');
    drawnow;
    GUIOperations.GUIPlot('plotJointSpace',idsim,handles,2,get(handles.undock_box,'Value'));
    GUIOperations.GUIPlot('plotJointSpace',fdsim,handles,2,get(handles.undock_box,'Value'));
    set(handles.status_text,'String','No simulation running');
    assignin('base','forward_dynamics_simulator',fdsim);
end

function toggle_visibility(dynamics_method,handles)
    if(strcmp(dynamics_method,'Forward Dynamics'))
        % Forward dynamics so hide all of the options
        set(handles.solver_class_text,'Visible','off');
        set(handles.solver_class_popup,'Visible','off');
%         set(handles.solver_type_text,'Visible','off');
%         set(handles.solver_type_popup,'Visible','off');
        set(handles.objective_text,'Visible','off');
        set(handles.objective_popup,'Visible','off');
        set(handles.constraint_text,'Visible','off');
        set(handles.constraint_popup,'Visible','off');
        set(handles.plot_type_text,'Visible','off');
        set(handles.plot_type_popup,'Visible','off');
        set(handles.objective_radio,'Visible','off');
        set(handles.objective_table,'Visible','off');
        set(handles.constraint_table,'Visible','off');
        set(handles.constraint_number_edit,'Visible','off');
        set(handles.tuning_parameter_text,'Visible','off');
        set(handles.tuning_parameter_popup,'Visible','off');
        set(handles.tuning_parameter_radio,'Visible','off');
        set(handles.tuning_parameter_table,'Visible','off');
    else
        % Inverse dynamics so let all of the options be viewed
        set(handles.solver_class_text,'Visible','on');
        set(handles.solver_class_popup,'Visible','on');
%         set(handles.solver_type_text,'Visible','on');
%         set(handles.solver_type_popup,'Visible','on');
        set(handles.objective_text,'Visible','on');
        set(handles.objective_popup,'Visible','on');
        set(handles.constraint_text,'Visible','on');
        set(handles.constraint_popup,'Visible','on');
        set(handles.plot_type_text,'Visible','on');
        set(handles.plot_type_popup,'Visible','on');
        objective_popup_Update(handles.objective_popup,handles);
        constraint_popup_Update(handles.constraint_popup,handles);
        tuning_parameter_popup_Update(handles.tuning_parameter_popup,handles);
    end
end

function initialise_popups(handles)
    % Updates
    solver_type_popup_update(handles.solver_type_popup,handles);
    dynamics_popup_Callback(handles.dynamics_popup, [], handles);
    objective_popup_Update(handles.objective_popup,handles);
    constraint_popup_Update(handles.constraint_popup,handles);
    tuning_parameter_popup_Update(handles.tuning_parameter_popup,handles);
    % Needed callbacks
    plot_type_popup_Callback(handles.plot_type_popup,[],handles);
    objective_popup_Callback(handles.objective_popup,[],handles);
    constraint_popup_Callback(handles.constraint_popup,[],handles);
    tuning_parameter_popup_Callback(handles.tuning_parameter_popup, [], handles);
end

function weight_number = get_weight_number(xmlObj,modObj)
    weight_links = str2double(xmlObj.getElementsByTagName('weight_links_multiplier').item(0).getFirstChild.getData);
    weight_cables = str2double(xmlObj.getElementsByTagName('weight_cables_multiplier').item(0).getFirstChild.getData);
    weight_constants = str2num(xmlObj.getElementsByTagName('weight_constants').item(0).getFirstChild.getData); %#ok<ST2NM>
    weight_number = weight_links*modObj.numLinks + weight_cables*modObj.numActuatorsActive + sum(weight_constants);
end
