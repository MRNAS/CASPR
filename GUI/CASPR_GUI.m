% The main GUI file for CASPR
%
% Author        : Jonathan EDEN
% Created       : 2016
% Description    :
%    Creates the main GUI window for users to use CASPR using a more
%    friendly interface. This is the main interface that connects to the
%    other GUI windows that perform more specific analyses.

%--------------------------------------------------------------------------
%% Constructor
%--------------------------------------------------------------------------
function varargout = CASPR_GUI(varargin)
    % CASPR_GUI MATLAB code for CASPR_GUI.fig
    %      CASPR_GUI, by itself, creates a new CASPR_GUI or raises the existing
    %      singleton*.
    %
    %      H = CASPR_GUI returns the handle to a new CASPR_GUI or the handle to
    %      the existing singleton*.
    %
    %      CASPR_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in CASPR_GUI.M with the given input arguments.
    %
    %      CASPR_GUI('Property','Value',...) creates a new CASPR_GUI or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before CASPR_GUI_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to CASPR_GUI_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %
    % See also: GUIDE, GUIDATA, GUIHANDLES

    % Edit the above text to modify the response to help CASPR_GUI

    % Last Modified by GUIDE v2.5 26-Feb-2016 17:56:58

    % Begin initialization code - DO NOT EDIT
    path_string = fileparts(mfilename('fullpath'));
    path_string = path_string(1:strfind(path_string, 'GUI')-2);
    p = path;
    if(isempty(strfind(p,[path_string,'\str'])))
        addpath(genpath(path_string))
    end
    
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @CASPR_GUI_OpeningFcn, ...
                       'gui_OutputFcn',  @CASPR_GUI_OutputFcn, ...
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
% --- Executes just before CASPR_GUI is made visible.
function CASPR_GUI_OpeningFcn(hObject, ~, handles, varargin)
    % This function has no output args, see OutputFcn.
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % varargin   command line arguments to CASPR_GUI (see VARARGIN)

    % Choose default command line output for CASPR_GUI
    handles.output = hObject;

    % Update handles structure
    guidata(hObject, handles);
    
%     Load previous information
    plot(rand(5)); % Hack to fix size.  Ideally removed at some point.
    loadState(handles);
    % UIWAIT makes CASPR_GUI wait for user response (see UIRESUME)
    % uiwait(handles.figure1);
end

% --- Outputs from this function are returned to the command line.
function varargout = CASPR_GUI_OutputFcn(~, ~, handles)
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
function OpenMenuItem_Callback(~, ~, ~)  %#ok<DEFNU>
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
% Model Popup
% --- Executes on selection change in model_popup.
function model_popup_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to model_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = get(hObject,'String') returns model_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from model_popup
    cable_popup_update(handles);
end

% --- Executes during object creation, after setting all properties.
function model_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to model_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
         set(hObject,'BackgroundColor','white');
    end
    e_list      =   enumeration('ModelConfigType');
    e_n         =   length(e_list);
    e_list_str  =   cell(1,e_n);
    for i=1:e_n
        temp_str = char(e_list(i));
        e_list_str{i} = temp_str(3:length(temp_str));
    end
    set(hObject, 'String', e_list_str);
end

% Cable Popup
% --- Executes on selection change in cable_popup.
function cable_popup_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to cable_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: contents = cellstr(get(hObject,'String')) returns cable_popup contents as cell array
    %        contents{get(hObject,'Value')} returns selected item from cable_popup
    generate_model_object(handles);
    % ADD PLOTTING OF THE OBJECT
end

% --- Executes during object creation, after setting all properties.
function cable_popup_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
    % hObject    handle to cable_popup (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    empty - handles not created until after all CreateFcns called

    % Hint: popupmenu controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    set(hObject, 'String', {'Choose a Model'});
end

%--------------------------------------------------------------------------
%% Push Buttons
%--------------------------------------------------------------------------
% Dynamics 
% --- Executes on button press in dynamics_button.
function dynamics_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to dynamics_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    saveState(handles);
    dynamics_GUI;
end

% Kinematics
% --- Executes on button press in kinematics_button.
function kinematics_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to kinematics_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    saveState(handles);
    kinematics_GUI;
end

% Workspace
% --- Executes on button press in workspace_button.
function workspace_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to workspace_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    saveState(handles);
    workspace_GUI;
end

% --- Executes on button press in update_button.
function update_button_Callback(~, ~, handles) %#ok<DEFNU>
% hObject    handle to update_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    modObj = getappdata(handles.cable_popup,'modObj');
    q_data = get(handles.qtable,'Data');
    modObj.update(q_data',zeros(modObj.numDofVars,1),zeros(modObj.numDofVars,1),zeros(modObj.numDofVars,1));
    cla;
    axis_range = getappdata(handles.cable_popup,'axis_range');
    MotionSimulator.PlotFrame(modObj, axis_range,handles.figure1);
end

% --- Executes on button press in control_button.
function control_button_Callback(~, ~, handles) %#ok<DEFNU>
    % hObject    handle to control_button (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    saveState(handles);
    control_GUI;
end

%--------------------------------------------------------------------------
% Additional Functions
%--------------------------------------------------------------------------
function generate_model_object(handles)
    % Generate the dynamics object
    contents = cellstr(get(handles.model_popup,'String'));
    model_type = contents{get(handles.model_popup,'Value')};
    model_config = ModelConfig(ModelConfigType.(['M_',model_type]));
    contents = cellstr(get(handles.cable_popup,'String'));
    cable_set_id = contents{get(handles.cable_popup,'Value')};
    modObj = model_config.getModel(cable_set_id);
    cla;
    display_range = model_config.displayRange;
    MotionSimulator.PlotFrame(modObj, display_range,handles.figure1);
    % Store the dynamics object
    setappdata(handles.cable_popup,'modObj',modObj);
    setappdata(handles.cable_popup,'axis_range',display_range);
    set(handles.model_label_text,'String',model_type);
    format_q_table(modObj.numDofs,handles.qtable);
end

function cable_popup_update(handles)
    % Generate the model_config object
    contents = cellstr(get(handles.model_popup,'String'));
    model_type = contents{get(handles.model_popup,'Value')};
    model_config = ModelConfig(ModelConfigType.(['M_',model_type]));
    % Determine the cable sets
%     cablesetsObj = model_config.cablesXmlObj.getElementsByTagName('cables').item(0).getElementsByTagName('cable_set');
%     cableset_str = cell(1,cablesetsObj.getLength);
%     % Extract the identifies from the cable sets
%     for i =1 :cablesetsObj.getLength
%         cablesetObj = cablesetsObj.item(i-1);
%         cableset_str{i} = char(cablesetObj.getAttribute('id'));
%     end
    cableset_str = model_config.getCableSetList();
    set(handles.cable_popup, 'Value', 1);
    set(handles.cable_popup, 'String', cableset_str);
    generate_model_object(handles);
end

function saveState(handles)
    % Save all of the settings
    state.model_popup_value     =   get(handles.model_popup,'value');
    state.cable_popup_value     =   get(handles.cable_popup,'value');
    contents                    =   get(handles.model_popup,'String');
    state.model_text            =   contents{state.model_popup_value};
    contents                    =   get(handles.cable_popup,'String');
    state.cable_text            =   contents{state.cable_popup_value};
    modObj                      =   getappdata(handles.cable_popup,'modObj');
    state.modObj                =   modObj;
    path_string = fileparts(mfilename('fullpath'));
    path_string = path_string(1:strfind(path_string, 'GUI')-2);
    % Check if the log folder exists
    if(exist([path_string,'/logs'],'dir')~=7)
        mkdir([path_string,'/logs']);        
    end
    save([path_string,'/logs/upcra_gui_state.mat'],'state');
end

function loadState(handles)
    % load all of the settings and initialise the values to match
    path_string = fileparts(mfilename('fullpath'));
    path_string = path_string(1:strfind(path_string, 'GUI')-2);
    file_name = [path_string,'/logs/upcra_gui_state.mat'];
    if(exist(file_name,'file'))
        load(file_name);
        set(handles.model_popup,'value',state.model_popup_value);
        cable_popup_update(handles);
        set(handles.cable_popup,'value',state.cable_popup_value);
        generate_model_object(handles);
    else
        set(handles.model_popup,'value',1);
        cable_popup_update(handles);
    end
end

function format_q_table(numDofs,qtable)
    set(qtable,'Data',zeros(1,numDofs));
    set(qtable,'ColumnWidth',{30});
    set(qtable,'ColumnEditable',true(1,numDofs));
    column_name = cell(1,numDofs);
    for i = 1:numDofs
        column_name{i} = ['q',num2str(i)];
    end
    set(qtable,'ColumnName',column_name);
end