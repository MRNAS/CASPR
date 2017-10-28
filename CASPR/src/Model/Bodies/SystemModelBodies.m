% System kinematics of the bodies for the system
%
% Please cite the following paper when using this for multilink cable
% robots:
% D. Lau, D. Oetomo, and S. K. Halgamuge, "Generalized Modeling of
% Multilink Cable-Driven Manipulators with Arbitrary Routing Using the
% Cable-Routing Matrix," IEEE Trans. Robot., vol. 29, no. 5, pp. 1102-1113,
% Oct. 2013.
%
% Author        : Darwin LAU
% Created       : 2011
% Description    :
%    Data structure that represents the kinematics of the bodies of the
% system, encapsulated within an array of BodyKinematics object. Also
% provides global matrices for the entire rigid body kinematics system.
classdef SystemModelBodies < handle
    properties
        q_ddot                  % Acceleration of joint space coordiantes
    end

    properties (SetAccess = private)
        % Objects
        bodies                  % Cell array of BodyModel objects
        
        % Degrees of freedom
        numDofs
        numDofVars
        numOPDofs
        numLinks
        numDofsActuated             % Number of actuated DoFs

        % Generalised coordinates of the system
        q                       % Joint space coordinates
        q_dot                   % Derivatives of joint space coordinates

        % Graphs
        connectivityGraph       % p x p connectivity matrix, if (i,j) = 1 means link i-1 is the parent of link j
        bodiesPathGraph         % p x p matrix that governs how to track to particular bodies, (i,j) = 1 means that to get to link j we must pass through link i

        % Operational Space coordinates of the system
        y       = [];           % Operational space coordinates
        y_dot   = [];           % Operational space velocity
        y_ddot  = [];           % Operational space acceleration

        % Jacobian Matrices - These matrices should probably be computed as
        % needed (dependent variable), but if it is a commonly used matrix
        % (i.e. accessed multiple times even if the system state does not
        % change) then storing it would be more efficient. However this
        % means that update must be performed through this class' update
        % function and not on the body's update directly. This makes sense
        % since just updating one body without updating the others would
        % cause inconsistency anyway.
        S                       % S matrix representing relationship between relative body velocities (joint) and generalised coordinates velocities
        S_dot                   % Derivative of S
        P                       % 6p x 6p matrix representing mapping between absolute body velocities (CoG) and relative body velocities (joint)
        W                       % W = P*S : 6p x n matrix representing mapping \dot{\mathbf{x}} = W \dot{\mathbf{q}}
        J     = [];             % J matrix representing relationship between generalised coordinate velocities and operational space coordinates
        J_dot = [];             % Derivative of J
        T     = [];             % Projection of operational coordinates

        % Gradient terms
        W_grad          = []; % The gradient tensor of the W matrix
        Minv_grad       = []; % The gradient tensor of the M^-1 matrix
        C_grad_q        = []; % The gradient (wrt q) of C
        C_grad_qdot     = []; % The gradient (wrt \dot{q}) of C
        G_grad          = []; % The gradient tensor of the W matrix

        % Absolute CoM velocities and accelerations (linear and angular)
        x_dot                   % Absolute velocities
        x_ddot                  % Absolute accelerations (x_ddot = W(q)*q_ddot + C_a(q,q_dot))
        C_a                     % Relationship between body and joint accelerations \ddot{\mathbf{x}} = W \ddot{\mathbf{q}} + C_a

        % Mass matrix
        massInertiaMatrix = [];       % Mass-inertia 6p x 6p matrix

        % M_y y_ddot + C_y + G_y = W (operational space)
        M_y = [];
        C_y = [];
        G_y = [];

        % M_b * q_ddot + C_b = G_b + w_b - V^T f (forces in body space)
        M_b = [];                        % Body mass-inertia matrix
        C_b = [];                        % Body C matrix
        G_b = [];                        % Body G matrix

        % M*q_ddot + C + G + w_e = - L^T f (forces in joint space)
        M = [];
        C = [];
        G = [];
        W_e = [];
        A = [];

        % Index for ease of computation
        index_k                      % A vector consisting of the first index to each joint

        % Flags
        is_symbolic                  % A flag to indicate whether the current pose is symbolic or a double
    end

    properties (Dependent)
        q_initial
        q_default
        q_dot_default
        q_ddot_default
        q_lb
        q_ub
        % Generalised coordinates time derivative (for special cases q_dot does not equal q_deriv)
        q_deriv
        
        tau                         % The joint actuator
        tauMin                      % The joint actuator minimum value
        tauMax                      % The joint actuator maximum value
        TAU_INVALID
        
        % Get array of dofs for each joint
        jointsNumDofVars
        jointsNumDofs
    end

    properties
        occupied                     % An object to keep flags for whether or not matrices are occupied
    end

    methods
        % Constructor for the class SystemModelBodies.  This determines the
        % numbers of degrees of freedom as well as initialises the
        % matrices.
        function b = SystemModelBodies(bodies)
            num_dofs = 0;
            num_dof_vars = 0;
            num_op_dofs = 0;
            num_dof_actuated = 0;
            b.index_k = MatrixOperations.Initialise([1,b.numLinks],0);
            for k = 1:length(bodies)
                b.index_k(k) = num_dofs + 1;
                num_dofs = num_dofs + bodies{k}.numDofs;
                num_dof_vars = num_dof_vars + bodies{k}.numDofVars;
                if (bodies{k}.joint.isActuated)
                    num_dof_actuated = num_dof_actuated + bodies{k}.joint.numDofs;
                end
            end
            b.bodies = bodies;
            b.numDofs = num_dofs;
            b.numDofVars = num_dof_vars;
            b.numOPDofs = num_op_dofs;
            b.numDofsActuated = num_dof_actuated;
            b.numLinks = length(b.bodies);

            b.connectivityGraph = MatrixOperations.Initialise([b.numLinks, b.numLinks],0);
            b.bodiesPathGraph = MatrixOperations.Initialise([b.numLinks, b.numLinks],0);
            b.S = MatrixOperations.Initialise([6*b.numLinks, b.numDofs],0);
            b.P = MatrixOperations.Initialise([6*b.numLinks, 6*b.numLinks],0);
            b.W = MatrixOperations.Initialise([6*b.numLinks, b.numDofs],0);
            b.T = MatrixOperations.Initialise([0,6*b.numLinks],0);

            % Construct joint actuation selection matrix
            b.A = zeros(b.numDofs, b.numDofsActuated);
            dof_ind = 0;
            dof_tau = 0;
            for k = 1:b.numLinks
                if (b.bodies{k}.isJointActuated)
                    b.A(dof_ind+1:dof_ind+b.bodies{k}.numDofs, dof_tau+1:dof_tau+b.bodies{k}.numDofs) = eye(b.bodies{k}.numDofs, b.bodies{k}.numDofs);
                    dof_tau = dof_tau + b.bodies{k}.numDofs;
                end
                dof_ind = dof_ind + b.bodies{k}.numDofs;
            end
            
            % Connects the objects of the system and create the
            % connectivity and body path graphs
            b.formConnectiveMap();
            b.occupied = BodyFlags();
        end

        % Update the kinematics of the body model for the entire
        % system using the generalised coordinates, velocity and
        % acceleration. This update function should also be called to
        % update the entire system, rather than calling the update function
        % for each body directly.
        function update(obj, q, q_dot, q_ddot, w_ext)
            % Assign q, q_dot, q_ddot
            obj.q = q;
            obj.q_dot = q_dot;
            obj.q_ddot = q_ddot;
            obj.W_e = w_ext;
            obj.is_symbolic = isa(q, 'sym');

            % Update each body first
            index_vars = 1;
            index_dofs = 1;
            for k = 1:obj.numLinks
                q_k = q(index_vars:index_vars+obj.bodies{k}.joint.numVars-1);
                q_dot_k = q_dot(index_dofs:index_dofs+obj.bodies{k}.joint.numDofs-1);
                q_ddot_k = q_ddot(index_dofs:index_dofs+obj.bodies{k}.joint.numDofs-1);
                obj.bodies{k}.update(q_k, q_dot_k, q_ddot_k);
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
                index_dofs = index_dofs + obj.bodies{k}.joint.numDofs;
            end

            % Now the global system updates
            % Set bodies kinematics (rotation matrices)
            for k = 1:obj.numLinks
                parent_link_num = obj.bodies{k}.parentLinkId;
                CASPR_log.Assert(parent_link_num < k, 'Problem with numbering of links with parent and child');

                % Determine rotation matrix
                % Determine joint location
                if parent_link_num > 0
                    obj.bodies{k}.R_0k = obj.bodies{parent_link_num}.R_0k*obj.bodies{k}.joint.R_pe;
                    obj.bodies{k}.r_OP = obj.bodies{k}.joint.R_pe.'*(obj.bodies{parent_link_num}.r_OP + obj.bodies{k}.r_Parent + obj.bodies{k}.joint.r_rel);
                else
                    obj.bodies{k}.R_0k = obj.bodies{k}.joint.R_pe;
                    obj.bodies{k}.r_OP = obj.bodies{k}.joint.R_pe.'*(obj.bodies{k}.r_Parent + obj.bodies{k}.joint.r_rel);
                end
                % Determine absolute position of COG
                obj.bodies{k}.r_OG  = obj.bodies{k}.r_OP + obj.bodies{k}.r_G;
                % Determine absolute position of link's ending position
                obj.bodies{k}.r_OPe = obj.bodies{k}.r_OP + obj.bodies{k}.r_Pe;
                % Determine absolute position of the operational space
                if(~isempty(obj.bodies{k}.op_space))
                    obj.bodies{k}.r_Oy  = obj.bodies{k}.r_OP + obj.bodies{k}.r_y;
                end
            end

            % Set S (joint state matrix) and S_dot
            index_dofs = 1;
            obj.S = MatrixOperations.Initialise([6*obj.numLinks,obj.numDofs],obj.is_symbolic);
            obj.S_dot = MatrixOperations.Initialise([6*obj.numLinks,obj.numDofs],obj.is_symbolic);
            for k = 1:obj.numLinks
                obj.S(6*k-5:6*k, index_dofs:index_dofs+obj.bodies{k}.joint.numDofs-1) = obj.bodies{k}.joint.S;
                obj.S_dot(6*k-5:6*k, index_dofs:index_dofs+obj.bodies{k}.joint.numDofs-1) = obj.bodies{k}.joint.S_dot;
                index_dofs = index_dofs + obj.bodies{k}.joint.numDofs;
            end

            % Set P (relationship with joint propagation)
            obj.P = MatrixOperations.Initialise([6*obj.numLinks,6*obj.numLinks],obj.is_symbolic);
            for k = 1:obj.numLinks
                body_k = obj.bodies{k};
                for a = 1:k
                    body_a = obj.bodies{a};
                    R_ka = body_k.R_0k.'*body_a.R_0k;
                    Pak = obj.bodiesPathGraph(a,k)*[R_ka*body_a.joint.R_pe.' -R_ka*MatrixOperations.SkewSymmetric(-body_a.r_OP + R_ka.'*body_k.r_OG); ...
                        zeros(3,3) R_ka];
                    obj.P(6*k-5:6*k, 6*a-5:6*a) = Pak;
                end
            end

            % W = P*S
            obj.W = obj.P*obj.S;
            
            % Determine x_dot
            obj.x_dot = obj.W*obj.q_dot;
            % Extract absolute velocities
            for k = 1:obj.numLinks
                obj.bodies{k}.v_OG = obj.x_dot(6*k-5:6*k-3);
                obj.bodies{k}.w = obj.x_dot(6*k-2:6*k);
            end

            % Determine x_ddot
            ang_mat = MatrixOperations.Initialise([6*obj.numLinks,6*obj.numLinks],obj.is_symbolic);
            for k = 1:obj.numLinks
                kp = obj.bodies{k}.parentLinkId;
                if (kp > 0)
                    w_kp = obj.bodies{kp}.w;
                else
                    w_kp = zeros(3,1);
                end
                w_k = obj.bodies{k}.w;
                ang_mat(6*k-5:6*k, 6*k-5:6*k) = [2*MatrixOperations.SkewSymmetric(w_kp) zeros(3,3); zeros(3,3) MatrixOperations.SkewSymmetric(w_k)];
            end

            obj.C_a = obj.P*obj.S_dot*obj.q_dot + obj.P*ang_mat*obj.S*obj.q_dot;
            for k = 1:obj.numLinks
                for a = 1:k
                    ap = obj.bodies{a}.parentLinkId;
                    if (ap > 0 && obj.bodiesPathGraph(a,k))
                        obj.C_a(6*k-5:6*k-3) = obj.C_a(6*k-5:6*k-3) + obj.bodies{k}.R_0k.'*obj.bodies{ap}.R_0k*cross(obj.bodies{ap}.w, cross(obj.bodies{ap}.w, obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel));
                    end
                end
                obj.C_a(6*k-5:6*k-3) = obj.C_a(6*k-5:6*k-3) + cross(obj.bodies{k}.w, cross(obj.bodies{k}.w, obj.bodies{k}.r_G));
            end
            obj.x_ddot = obj.P*obj.S*obj.q_ddot + obj.C_a;

            % Extract absolute accelerations
            for k = 1:obj.numLinks
                obj.bodies{k}.a_OG = obj.x_ddot(6*k-5:6*k-3);
                obj.bodies{k}.w_dot = obj.x_ddot(6*k-2:6*k);
            end

            % The operational space variables
            if(obj.occupied.op_space)
                % Now determine the operational space vector y
                obj.y = MatrixOperations.Initialise([obj.numOPDofs,1],obj.is_symbolic); l = 1;
                for k = 1:obj.numLinks
                    if(~isempty(obj.bodies{k}.op_space))
                        n_y = obj.bodies{k}.numOPDofs;
                        obj.y(l:l+n_y-1) = obj.bodies{k}.op_space.extractOpSpace(obj.bodies{k}.r_Oy,obj.bodies{k}.R_0k);
                        l = l + n_y;
                    end
                end

                % Set Q (relationship with joint propagation for operational space)
                Q = MatrixOperations.Initialise([6*obj.numLinks,6*obj.numLinks],obj.is_symbolic);
                for k = 1:obj.numLinks
                    body_k = obj.bodies{k};
                    for a = 1:k
                        body_a = obj.bodies{a};
                        R_ka = body_k.R_0k.'*body_a.R_0k;
                        Qak = [body_k.R_0k,zeros(3);zeros(3),body_k.R_0k]*(obj.bodiesPathGraph(a,k)*[R_ka*body_a.joint.R_pe.' -R_ka*MatrixOperations.SkewSymmetric(-body_a.r_OP + R_ka.'*body_k.r_Oy); ...
                            zeros(3,3) R_ka]);
                        Q(6*k-5:6*k, 6*a-5:6*a) = Qak;
                    end
                end
                % J = T*Q*S
                obj.J = obj.T*Q*obj.S;
                % Determine y_dot
                obj.y_dot = obj.J*obj.q_dot;

                % Determine J_dot
                temp_j_dot = Q*obj.S_dot + Q*ang_mat*obj.S;
                for k = 1:obj.numLinks
                    for a = 1:k
                        ap = obj.bodies{a}.parentLinkId;
                        if (ap > 0 && obj.bodiesPathGraph(a,k))
                            temp_j_dot(6*k-5:6*k-3,:) = temp_j_dot(6*k-5:6*k-3,:) - ...
                                obj.bodies{k}.R_0k*obj.bodies{k}.R_0k.'*obj.bodies{ap}.R_0k*MatrixOperations.SkewSymmetric(obj.bodies{ap}.w)*MatrixOperations.SkewSymmetric(obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel)*obj.W(6*ap-2:6*ap,:);
                        end
                    end
                    temp_j_dot(6*k-5:6*k-3,:) = temp_j_dot(6*k-5:6*k-3,:) - obj.bodies{k}.R_0k*MatrixOperations.SkewSymmetric(obj.bodies{k}.w)*MatrixOperations.SkewSymmetric(obj.bodies{k}.r_y)*obj.W(6*k-2:6*k,:);
                end
                obj.J_dot = obj.T*temp_j_dot;
                obj.y_ddot = obj.J_dot*q_dot + obj.J*obj.q_ddot;
            end

            % The dynamics variables
            if(obj.occupied.dynamics)
                obj.updateDynamics();
            end

            % The Hessian Variables
            if(obj.occupied.hessian)
                obj.updateHessian();
            end

            % The linearisation variables
            if(obj.occupied.linearisation)
                obj.updateLinearisation();
            end
        end

        % Update the dynamics of the body model for the entire
        % system using the generalised coordinates, velocity and
        % acceleration. This update function is only called when a dynamics
        % object has been used.
        function updateDynamics(obj)
            % Body equation of motion terms
            obj.M_b = obj.massInertiaMatrix*obj.W;
            obj.C_b = obj.massInertiaMatrix*obj.C_a;
            for k = 1:obj.numLinks
                obj.C_b(6*k-2:6*k) = obj.C_b(6*k-2:6*k) + cross(obj.bodies{k}.w, obj.bodies{k}.I_G*obj.bodies{k}.w);
            end
            obj.G_b = MatrixOperations.Initialise([6*obj.numLinks,1],obj.is_symbolic);
            for k = 1:obj.numLinks
                obj.G_b(6*k-5:6*k-3) = obj.bodies{k}.R_0k.'*[0; 0; -obj.bodies{k}.m*SystemModel.GRAVITY_CONSTANT];
            end

            % Joint space equation of motion terms
            obj.M =   obj.W.' * obj.M_b;
            obj.C =   obj.W.' * obj.C_b;
            obj.G = - obj.W.' * obj.G_b;
            
            % Operational space equation of motion terms
            if(obj.occupied.op_space)
                obj.M_y = inv(obj.J*inv(obj.M)*obj.J'); %#ok<MINV>
                Jpinv   = obj.J'/(obj.J*obj.J');
                obj.C_y = Jpinv'*obj.C - obj.M_y*obj.J_dot*obj.q_dot;
                obj.G_y = Jpinv'*obj.G;
            end
        end
        
        % Update the hessian of the body model for the entire
        % system using the generalised coordinates, velocity and
        % acceleration. This update function is only called when a hessian
        % object has been used.
        function updateHessian(obj)
            % This function computes the tensor W_grad = P_grad*S +
            % S_grad*P
            % In the interest of saving memory blockwise computation will
            % be used in place of storing complete gradient tensors
            obj.W_grad = MatrixOperations.Initialise([6*obj.numLinks,obj.numDofs,obj.numDofs],obj.is_symbolic);
            % At the moment I will separate the two loops
            for k = 1:obj.numLinks
                index_a_dofs = 1;
                for a = 1:k
                    S_a_grad = obj.bodies{a}.joint.S_grad;
                    body_dofs = obj.bodies{a}.joint.numDofs;
                    P_ka = obj.P(6*k-5:6*k, 6*a-5:6*a);
                    % S_Grad component
                    % Add P \nabla S
					obj.W_grad(6*k-5:6*k,index_a_dofs:index_a_dofs+body_dofs-1,index_a_dofs:index_a_dofs+body_dofs-1) = obj.W_grad(6*k-5:6*k,index_a_dofs:index_a_dofs+body_dofs-1,index_a_dofs:index_a_dofs+body_dofs-1) + TensorOperations.LeftMatrixProduct(P_ka,S_a_grad,obj.is_symbolic);
					% P_grad component
                    P_ka_grad = obj.compute_Pka_grad(k,a);
                    % Add \nabla P S
                    obj.W_grad(6*k-5:6*k,index_a_dofs:index_a_dofs+body_dofs-1,1:obj.numDofs) = obj.W_grad(6*k-5:6*k,index_a_dofs:index_a_dofs+body_dofs-1,1:obj.numDofs) + TensorOperations.RightMatrixProduct(P_ka_grad,obj.S(6*a-5:6*a, index_a_dofs:index_a_dofs+body_dofs-1),obj.is_symbolic);
                    index_a_dofs = index_a_dofs + body_dofs;
                end
            end
        end

        % Update the linearisation of the body model for the entire
        % system using the generalised coordinates, velocity and
        % acceleration. This update function is only called when a
        % linearisation object has been used.
        function updateLinearisation(obj)
            % Store the transpose gradient as this will be reused.
            W_t_grad = TensorOperations.Transpose(obj.W_grad,[1,2],obj.is_symbolic);
            % M_grad
            Minv = inv(obj.M);
            temp_tensor =  TensorOperations.RightMatrixProduct(W_t_grad,(obj.massInertiaMatrix*obj.W),obj.is_symbolic) + ...
                                    TensorOperations.LeftMatrixProduct((obj.W.'*obj.massInertiaMatrix),obj.W_grad,obj.is_symbolic);
            obj.Minv_grad = -TensorOperations.LeftRightMatrixProduct(Minv,temp_tensor,obj.is_symbolic);
            % C_grad_q - Note C_1 = W'M_BP(\dot{S}+XS)\dot{q} and C_2 = W'c
            ang_mat = MatrixOperations.Initialise([6*obj.numLinks,6*obj.numLinks],obj.is_symbolic);
            for k = 1:obj.numLinks
                kp = obj.bodies{k}.parentLinkId;
                if (kp > 0)
                    w_kp = obj.bodies{kp}.w;
                else
                    w_kp = zeros(3,1);
                end
                w_k = obj.bodies{k}.w;
                ang_mat(6*k-5:6*k, 6*k-5:6*k) = [2*MatrixOperations.SkewSymmetric(w_kp) zeros(3,3); zeros(3,3) MatrixOperations.SkewSymmetric(w_k)];
            end
            % First term is not computed as a block
            obj.C_grad_q        =   TensorOperations.VectorProduct(W_t_grad,obj.massInertiaMatrix*obj.P*(obj.S_dot + ang_mat*obj.S)*obj.q_dot,2,obj.is_symbolic);
            WtM                 =   obj.W.'*obj.massInertiaMatrix;
            obj.C_grad_qdot     =   WtM*obj.P*(obj.S_dot + ang_mat*obj.S);
            % Block computation
            for k = 1:obj.numLinks
                index_a_dofs = 1;
                m_k = obj.bodies{k}.m;
                for a = 1:k
                    body_dofs = obj.bodies{a}.joint.numDofs;
                    ap = obj.bodies{a}.parentLinkId;
                    % Derive the original block matrices
                    % X_a
                    X_a = ang_mat(6*a-5:6*a, 6*a-5:6*a);
                    % \dot{S}_a + X_aS_a
                    S_deriv_a = obj.bodies{a}.joint.S_dot + X_a*obj.bodies{a}.joint.S;
                    % P_ka
                    P_ka = obj.P(6*k-5:6*k, 6*a-5:6*a);
                    % Block gradient computation
                    % Grad(P_ka)S_deriv_a\dot{q}_a component
                    P_ka_grad = obj.compute_Pka_grad(k,a);
                    block_grad = TensorOperations.VectorProduct(P_ka_grad,S_deriv_a*obj.q_dot(index_a_dofs:index_a_dofs+body_dofs-1),2,obj.is_symbolic);
                    % P_ka Grad(S_deriv_a)\dot{q}_a component
                    % Grad(S_deriv_a) = Grad(\dot{S}) + Grad(X_a)S + X_a Grad(S)
                    % Initialise the terms
                    S_deriv_grad_q = MatrixOperations.Initialise([6,body_dofs,obj.numDofs],obj.is_symbolic);
                    S_deriv_grad_q_dot = MatrixOperations.Initialise([6,body_dofs,obj.numDofs],obj.is_symbolic);
                    % Add the Grad(\dot{S}) terms
                    S_deriv_grad_q(:,:,index_a_dofs:index_a_dofs+body_dofs-1) = obj.bodies{a}.joint.S_dot_grad;
                    S_deriv_grad_q_dot(:,:,index_a_dofs:index_a_dofs+body_dofs-1) = obj.bodies{a}.joint.S_grad;
                    % Grad(X_a)S
                    X_a_grad_q = MatrixOperations.Initialise([6,6,obj.numDofs],obj.is_symbolic);
                    X_a_grad_q_dot = MatrixOperations.Initialise([6,6,obj.numDofs],obj.is_symbolic);
                    
                    [w_ap_grad_q,w_ap_grad_q_dot]   = obj.generate_omega_grad(ap);
                    [w_a_grad_q,w_a_grad_q_dot]     = obj.generate_omega_grad(a);
                    for i=1:obj.numDofs
                        X_a_grad_q(1:3,1:3,i) = 2*MatrixOperations.SkewSymmetric(w_ap_grad_q(:,i));
                        X_a_grad_q(4:6,4:6,i) = MatrixOperations.SkewSymmetric(w_a_grad_q(:,i));
                        X_a_grad_q_dot(1:3,1:3,i) = 2*MatrixOperations.SkewSymmetric(w_ap_grad_q_dot(:,i));
                        X_a_grad_q_dot(4:6,4:6,i) = MatrixOperations.SkewSymmetric(w_a_grad_q_dot(:,i));
                    end
                    S_deriv_grad_q = S_deriv_grad_q + TensorOperations.RightMatrixProduct(X_a_grad_q,obj.bodies{a}.joint.S,obj.is_symbolic);
                    S_deriv_grad_q_dot = S_deriv_grad_q_dot + TensorOperations.RightMatrixProduct(X_a_grad_q_dot,obj.bodies{a}.joint.S,obj.is_symbolic);
                    % X_a Grad(S)
                    S_deriv_grad_q(:,:,index_a_dofs:index_a_dofs+body_dofs-1) = S_deriv_grad_q(:,:,index_a_dofs:index_a_dofs+body_dofs-1) + TensorOperations.LeftMatrixProduct(X_a,obj.bodies{a}.joint.S_grad,obj.is_symbolic);
                    
                    % Final computation
                    block_grad = block_grad + P_ka*TensorOperations.VectorProduct(S_deriv_grad_q,obj.q_dot(index_a_dofs:index_a_dofs+body_dofs-1),2,obj.is_symbolic);
                    
                    % Map the block gradient back into the relevant term
                    obj.C_grad_q = obj.C_grad_q + WtM(:,6*k-5:6*k)*block_grad;

                    % C_grad_q_dot
                    obj.C_grad_qdot = obj.C_grad_qdot + WtM(:,6*k-5:6*k)*P_ka*TensorOperations.VectorProduct(S_deriv_grad_q_dot,obj.q_dot(index_a_dofs:index_a_dofs+body_dofs-1),2,obj.is_symbolic);

                    % The c term
                    if(ap==0)
                        R_kam1 = obj.bodies{k}.R_0k.';
                        ap_w = zeros(3,1);
                    else
                        R_kam1 = obj.bodies{k}.R_0k.'*obj.bodies{ap}.R_0k;
                        ap_w = obj.bodies{ap}.w;
                    end
                    R_kam1_grad = obj.compute_Rka_grad(k,ap);
                            
                    % Grad(W)*c
                    obj.C_grad_q = obj.C_grad_q + m_k*TensorOperations.VectorProduct(W_t_grad(:,6*k-5:6*k-3,:),R_kam1*cross(ap_w, cross(ap_w, obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel)),2,obj.is_symbolic);
                    % Grad of R
                    obj.C_grad_q = obj.C_grad_q + m_k*obj.W(6*k-5:6*k-3,:).'*TensorOperations.VectorProduct(R_kam1_grad,cross(ap_w, cross(ap_w, obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel)),2,obj.is_symbolic);
                    % Grad of omega
                    obj.C_grad_q = obj.C_grad_q + m_k*obj.W(6*k-5:6*k-3,:).'*R_kam1*TensorOperations.VectorProduct(0.5*X_a_grad_q(1:3,1:3,:),cross(ap_w, obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel),2,obj.is_symbolic);
                    % Grad of omega
                    obj.C_grad_q = obj.C_grad_q + m_k*obj.W(6*k-5:6*k-3,:).'*R_kam1*MatrixOperations.SkewSymmetric(ap_w)*TensorOperations.VectorProduct(0.5*X_a_grad_q(1:3,1:3,:),obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel,2,obj.is_symbolic);
                    % Grad of r
                    obj.C_grad_q(:,index_a_dofs:index_a_dofs+body_dofs-1) = obj.C_grad_q(:,index_a_dofs:index_a_dofs+body_dofs-1) + m_k*obj.W(6*k-5:6*k-3,:).'*R_kam1*MatrixOperations.SkewSymmetric(ap_w)*MatrixOperations.SkewSymmetric(ap_w)*obj.bodies{a}.joint.S(1:3,:);

                    % q_dot
                    obj.C_grad_qdot = obj.C_grad_qdot + m_k*obj.W(6*k-5:6*k-3,:).'*R_kam1*TensorOperations.VectorProduct(0.5*X_a_grad_q_dot(1:3,1:3,:),cross(ap_w, obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel),2,obj.is_symbolic);
                    obj.C_grad_qdot = obj.C_grad_qdot + m_k*obj.W(6*k-5:6*k-3,:).'*R_kam1*MatrixOperations.SkewSymmetric(ap_w)*TensorOperations.VectorProduct(0.5*X_a_grad_q_dot(1:3,1:3,:),obj.bodies{a}.r_Parent + obj.bodies{a}.joint.r_rel,2,obj.is_symbolic);
                    
                    % update a_dofs
                    index_a_dofs = index_a_dofs + body_dofs;
                end
                % This is where the other terms go.  They are pretty much
                % Grad(W)*c
                obj.C_grad_q = obj.C_grad_q + m_k*TensorOperations.VectorProduct(W_t_grad(:,6*k-5:6*k-3,:),cross(obj.bodies{k}.w, cross(obj.bodies{k}.w, obj.bodies{k}.r_G)),2,obj.is_symbolic);
                % Grad of omega
                obj.C_grad_q = obj.C_grad_q + m_k*obj.W(6*k-5:6*k-3,:).'*TensorOperations.VectorProduct(X_a_grad_q(4:6,4:6,:),cross(obj.bodies{k}.w, obj.bodies{k}.r_G),2,obj.is_symbolic);
                % Grad of omega
                obj.C_grad_q = obj.C_grad_q + m_k*obj.W(6*k-5:6*k-3,:).'*MatrixOperations.SkewSymmetric(obj.bodies{k}.w)*TensorOperations.VectorProduct(X_a_grad_q(4:6,4:6,:),obj.bodies{k}.r_G,2,obj.is_symbolic);
                %
                obj.C_grad_q = obj.C_grad_q + TensorOperations.VectorProduct(W_t_grad(:,6*k-2:6*k,:),cross(obj.bodies{k}.w, obj.bodies{k}.I_G*obj.bodies{k}.w),2,obj.is_symbolic);
                obj.C_grad_q = obj.C_grad_q + obj.W(6*k-2:6*k,:).'*TensorOperations.VectorProduct(X_a_grad_q(4:6,4:6,:),obj.bodies{k}.I_G*obj.bodies{k}.w,2,obj.is_symbolic);
                obj.C_grad_q = obj.C_grad_q + obj.W(6*k-2:6*k,:).'*MatrixOperations.SkewSymmetric(obj.bodies{k}.w)*obj.bodies{k}.I_G*w_a_grad_q;

                % q_dot
                obj.C_grad_qdot = obj.C_grad_qdot + m_k*obj.W(6*k-5:6*k-3,:).'*TensorOperations.VectorProduct(X_a_grad_q_dot(4:6,4:6,:),cross(obj.bodies{k}.w, obj.bodies{k}.r_G),2,obj.is_symbolic);
                obj.C_grad_qdot = obj.C_grad_qdot + m_k*obj.W(6*k-5:6*k-3,:).'*MatrixOperations.SkewSymmetric(obj.bodies{k}.w)*TensorOperations.VectorProduct(X_a_grad_q_dot(4:6,4:6,:),obj.bodies{k}.r_G,2,obj.is_symbolic);
                %
                obj.C_grad_qdot = obj.C_grad_qdot + obj.W(6*k-2:6*k,:).'*TensorOperations.VectorProduct(X_a_grad_q_dot(4:6,4:6,:),obj.bodies{k}.I_G*obj.bodies{k}.w,2,obj.is_symbolic);
                obj.C_grad_qdot = obj.C_grad_qdot + obj.W(6*k-2:6*k,:).'*MatrixOperations.SkewSymmetric(obj.bodies{k}.w)*obj.bodies{k}.I_G*w_a_grad_q_dot;
            end
            % G_grad
            temp_grad = MatrixOperations.Initialise([6*obj.numLinks,obj.numDofs],obj.is_symbolic);
            for k = 1:obj.numLinks
                R_k0_grad = obj.compute_Rka_grad(k,0);
                temp_grad(6*k-5:6*k-3,:) = TensorOperations.VectorProduct(R_k0_grad,[0; 0; -obj.bodies{k}.m*SystemModel.GRAVITY_CONSTANT],2,obj.is_symbolic);
            end
            obj.G_grad = -TensorOperations.VectorProduct(W_t_grad,obj.G_b,2,obj.is_symbolic) - obj.W.'*temp_grad;
        end

        % Supporting function to connect all of the parent and child bodies
        function formConnectiveMap(obj)
            for k = 1:obj.numLinks
                obj.connectBodies(obj.bodies{k}.parentLinkId, k, obj.bodies{k}.r_Parent);
            end
        end

        % Supporting function to connect a particular child to a parent
        function connectBodies(obj, parent_link_num, child_link_num, r_parent_loc)
            CASPR_log.Assert(parent_link_num < child_link_num, 'Parent link number must be smaller than child');
            CASPR_log.Assert(~isempty(obj.bodies{child_link_num}), 'Child link does not exist');
            if parent_link_num > 0
                CASPR_log.Assert(~isempty(obj.bodies{parent_link_num}), 'Parent link does not exist');
            end

            obj.bodiesPathGraph(child_link_num, child_link_num) = 1;
            child_link = obj.bodies{child_link_num};
            if parent_link_num == 0
                parent_link = [];
            else
                parent_link = obj.bodies{parent_link_num};
            end
            child_link.addParent(parent_link, r_parent_loc);
            obj.connectivityGraph(parent_link_num+1, child_link_num) = 1;

            if (parent_link_num > 0)
                obj.bodiesPathGraph(parent_link_num, child_link_num) = 1;
                obj.bodiesPathGraph(:, child_link_num) = obj.bodiesPathGraph(:, child_link_num) | obj.bodiesPathGraph(:, parent_link_num);
            end
        end

        % A function to integrate the joint space.
        function q = qIntegrate(obj, q0, q_dot, dt)
            index_vars = 1;
            q = zeros(size(q0));
            for k = 1:obj.numLinks
                q(index_vars:index_vars+obj.bodies{k}.joint.numVars-1) = obj.bodies{k}.joint.QIntegrate(q0, q_dot, dt);
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
            end
        end
        
        % Create the mass inertia matrix for the system from the joint mass
        % inertia matrices.
        function createMassInertiaMatrix(obj)
            obj.massInertiaMatrix = zeros(6*obj.numLinks, 6*obj.numLinks);
            for k = 1:obj.numLinks
                obj.massInertiaMatrix(6*k-5:6*k, 6*k-5:6*k) = [obj.bodies{k}.m*eye(3) zeros(3,3); zeros(3,3) obj.bodies{k}.I_G];
            end
        end
                
        % Calculate the internal matrices for the quadratic form of the
        % Coriolis/Centrifugal forces.
        function N = calculateN(obj)
            % Initialisiation
            flag = isa(obj.q,'sym');
            MassInertiaMatrix = obj.massInertiaMatrix;
            % PS_dot term
            n_q = length(obj.q_dot); n_l = obj.numLinks;
            N_j = MatrixOperations.Initialise([n_q,n_q^2],flag);
            A = MatrixOperations.Initialise([6*n_l,n_q],flag);
            offset_x = 1; offset_y = 1;
            for i=1:n_l
                [N_jt,A_t] = obj.bodies{i}.joint.QuadMatrix(obj.q);
                n_qt = size(N_jt,1);
                N_j(offset_x:offset_x+n_qt-1,(i-1)*n_q+offset_y:(i-1)*n_q+offset_y+n_qt^2-1) = N_jt;
                A((i-1)*6+1:(i-1)*6+6,offset_x:offset_x+n_qt-1) = A_t;
                offset_x = offset_x + n_qt; offset_y = offset_y + n_qt^2;
            end
            % Project correctly
            C1 = MatrixOperations.MatrixProdLeftQuad(obj.W.'*MassInertiaMatrix*obj.P*A,N_j);

            % P_dotS term
            C2 = MatrixOperations.Initialise([n_q,n_q^2],flag);
            T_t = zeros(6*n_l,3);
            T_r = zeros(6*n_l,3);
            for i=1:n_l
                ip = obj.bodies{i}.parentLinkId;
                if (ip > 0)
                    W_ip = obj.W(6*(ip-1)+4:6*(ip-1)+6,:);
                else
                    W_ip = zeros(3,n_q);
                end
                W_i     =   obj.W(6*(i-1)+4:6*(i-1)+6,:);
                N_t     =   MatrixOperations.GenerateMatrixQuadCross(2*W_ip,obj.S(6*(i-1)+1:6*(i-1)+3,:));
                N_r     =   MatrixOperations.GenerateMatrixQuadCross(W_i,obj.S(6*(i-1)+4:6*(i-1)+6,:));
                T_t(6*(i-1)+1:6*(i-1)+3,:) = eye(3);
                T_r(6*(i-1)+4:6*(i-1)+6,:) = eye(3);
                C2 = C2 + MatrixOperations.MatrixProdLeftQuad(obj.W.'*MassInertiaMatrix*obj.P*T_t,N_t) + MatrixOperations.MatrixProdLeftQuad(obj.W.'*MassInertiaMatrix*obj.P*T_r,N_r);
                T_t(6*(i-1)+1:6*(i-1)+3,:) = zeros(3);
                T_r(6*(i-1)+4:6*(i-1)+6,:) = zeros(3);
            end

            % \omega \times \omega \times r
            C3 = MatrixOperations.Initialise([n_q,n_q^2],flag);
            for i = 1:n_l
                N_t = MatrixOperations.Initialise([n_q,3*n_q],flag);
                for j = 1:i
                    jp = obj.bodies{j}.parentLinkId;
                    if (jp > 0 && obj.bodiesPathGraph(j,i))
                        W_jp = obj.W(6*(jp-1)+4:6*(jp-1)+6,:);
                        R = MatrixOperations.SkewSymmetric(obj.bodies{j}.r_Parent + obj.bodies{j}.joint.r_rel)*W_jp;
                        N_tt = -MatrixOperations.GenerateMatrixQuadCross(W_jp,R);
                        N_t = N_t + MatrixOperations.MatrixProdLeftQuad(obj.bodies{i}.R_0k.'*obj.bodies{jp}.R_0k,N_tt);
                    end
                end
                W_i = obj.W(6*(i-1)+4:6*(i-1)+6,:);
                R = MatrixOperations.SkewSymmetric(obj.bodies{1}.r_G)*W_i;
                N_tt = -MatrixOperations.GenerateMatrixQuadCross(W_i,R);
                N_t = N_t + N_tt;
                T_t(6*(i-1)+1:6*(i-1)+3,:) = eye(3);
                C3 = C3 + MatrixOperations.MatrixProdLeftQuad(obj.W.'*MassInertiaMatrix*T_t,N_t);
                T_t(6*(i-1)+1:6*(i-1)+3,:) = zeros(3);
            end

            % \omega \times I_G \omega
            C4 = MatrixOperations.Initialise([n_q,n_q^2],flag);
            for i = 1:n_l
                W_i = obj.W(6*(i-1)+4:6*(i-1)+6,:);
                N_r = MatrixOperations.GenerateMatrixQuadCross(W_i,obj.bodies{i}.I_G*W_i);
                T_r(6*(i-1)+4:6*(i-1)+6,:) = eye(3);
                C4 = C4 + MatrixOperations.MatrixProdLeftQuad(obj.W.'*T_r,N_r);
                T_r(6*(i-1)+4:6*(i-1)+6,:) = zeros(3);
            end
            % Compute N
            N = C1 + C2 + C3 + C4;
            if(flag)
                N = simplify(N);
                V = MatrixOperations.Initialise([n_q,1],flag);
                for i=1:n_q
                    V(i) = obj.q_dot.'*N(:,(i-1)*n_q+1:(i-1)*n_q+n_q)*obj.q_dot;
                end
                simplify(V)
            end
        end

        % Load the operational space xml object
        function loadOpXmlObj(obj,op_space_xmlobj)
            obj.occupied.op_space = true;
            % Load the op space
            CASPR_log.Assert(strcmp(op_space_xmlobj.getNodeName, 'op_set'), 'Root element should be <op_set>');
            % Go into the cable set
            allOPItems = op_space_xmlobj.getChildNodes;

            num_ops = allOPItems.getLength;
            % Creates all of the operational spaces first first
            for k = 1:num_ops
                % Java uses 0 indexing
                currentOPItem = allOPItems.item(k-1);

                type = char(currentOPItem.getNodeName);
                if (strcmp(type, 'position'))
                    op_space = OpPosition.LoadXmlObj(currentOPItem);
                elseif(strcmp(type, 'orientation_euler_xyz'))
                    op_space = OpOrientationEulerXYZ.LoadXmlObj(currentOPItem);
                elseif(strcmp(type, 'pose_euler_xyz'))
                    op_space = OpPoseEulerXYZ.LoadXmlObj(currentOPItem);
                else
                    CASPR_log.Printf(sprintf('Unknown link type: %s', type),CASPRLogLevel.ERROR);
                end
                parent_link = op_space.link;
                obj.bodies{parent_link}.attachOPSpace(op_space);
                % Should add some protection to ensure that one OP_Space
                % per link
            end
            num_op_dofs = 0;
            for k = 1:length(obj.bodies)
                num_op_dofs = num_op_dofs + obj.bodies{k}.numOPDofs;
            end
            obj.numOPDofs = num_op_dofs;

            obj.T = MatrixOperations.Initialise([obj.numOPDofs,6*obj.numLinks],0);
            l = 1;
            for k = 1:length(obj.bodies)
                if(~isempty(obj.bodies{k}.op_space))
                    n_y = obj.bodies{k}.numOPDofs;
                    obj.T(l:l+n_y-1,6*k-5:6*k) = obj.bodies{k}.op_space.getSelectionMatrix();
                    l = l + n_y;
                end
            end
        end

        % -------
        % Getters
        % -------        
        function q = get.q_initial(obj)
            q = zeros(obj.numDofVars, 1);
            index_vars = 1;
            for k = 1:obj.numLinks
                q(index_vars:index_vars+obj.bodies{k}.joint.numVars-1) = obj.bodies{k}.joint.q_initial;
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
            end
        end
        
        function q = get.q_default(obj)
            q = zeros(obj.numDofVars, 1);
            index_vars = 1;
            for k = 1:obj.numLinks
                q(index_vars:index_vars+obj.bodies{k}.joint.numVars-1) = obj.bodies{k}.joint.q_default;
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
            end
        end

        function q_dot = get.q_dot_default(obj)
            q_dot = zeros(obj.numDofs, 1);
            index_dofs = 1;
            for k = 1:obj.numLinks
                q_dot(index_dofs:index_dofs+obj.bodies{k}.joint.numDofs-1) = obj.bodies{k}.joint.q_dot_default;
                index_dofs = index_dofs + obj.bodies{k}.joint.numDofs;
            end
        end

        function q_ddot = get.q_ddot_default(obj)
            q_ddot = zeros(obj.numDofs, 1);
            index_dofs = 1;
            for k = 1:obj.numLinks
                q_ddot(index_dofs:index_dofs+obj.bodies{k}.joint.numDofs-1) = obj.bodies{k}.joint.q_ddot_default;
                index_dofs = index_dofs + obj.bodies{k}.joint.numDofs;
            end
        end

        function q_lb = get.q_lb(obj)
            q_lb = zeros(obj.numDofVars, 1);
            index_vars = 1;
            for k = 1:obj.numLinks
                q_lb(index_vars:index_vars+obj.bodies{k}.joint.numVars-1) = obj.bodies{k}.joint.q_lb;
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
            end
        end

        function q_ub = get.q_ub(obj)
            q_ub = zeros(obj.numDofVars, 1);
            index_vars = 1;
            for k = 1:obj.numLinks
                q_ub(index_vars:index_vars+obj.bodies{k}.joint.numVars-1) = obj.bodies{k}.joint.q_ub;
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
            end
        end

        function q_deriv = get.q_deriv(obj)
            q_deriv = zeros(obj.numDofVars, 1);
            index_vars = 1;
            for k = 1:obj.numLinks
                q_deriv(index_vars:index_vars+obj.bodies{k}.joint.numVars-1) = obj.bodies{k}.joint.q_deriv;
                index_vars = index_vars + obj.bodies{k}.joint.numVars;
            end
        end

        function M_y = get.M_y(obj)
            if(~obj.occupied.dynamics)
                if(~obj.occupied.op_space)
                    M_y = [];
                    return;
                else
                    obj.createMassInertiaMatrix();
                    obj.occupied.dynamics = true;
                    obj.updateDynamics();
                end
            end
            M_y = obj.M_y;
        end

        function C_y = get.C_y(obj)
            if(~obj.occupied.dynamics)
                if(~obj.occupied.op_space)
                    C_y = [];
                    return;
                else
                    obj.createMassInertiaMatrix();
                    obj.occupied.dynamics = true;
                    obj.updateDynamics();
                end
            end
            C_y = obj.C_y;
        end

        function G_y = get.G_y(obj)
            if(~obj.occupied.dynamics)
                if(~obj.occupied.op_space)
                    G_y = [];
                    return;
                else
                    obj.createMassInertiaMatrix();
                    obj.occupied.dynamics = true;
                    obj.updateDynamics();
                end                
            end
            G_y = obj.G_y;
        end

        function M_b = get.M_b(obj)
            if(~obj.occupied.dynamics)
                obj.createMassInertiaMatrix();
                obj.occupied.dynamics = true;
                obj.updateDynamics();
            end
            M_b = obj.M_b;
        end

        function C_b = get.C_b(obj)
            if(~obj.occupied.dynamics)
                obj.createMassInertiaMatrix();
                obj.occupied.dynamics = true;
                obj.updateDynamics();
            end
            C_b = obj.C_b;
        end

        function G_b = get.G_b(obj)
            if(~obj.occupied.dynamics)
                obj.createMassInertiaMatrix();
                obj.occupied.dynamics = true;
                obj.updateDynamics();
            end
            G_b = obj.G_b;
        end

        function M = get.M(obj)
            if(~obj.occupied.dynamics)
                obj.createMassInertiaMatrix();
                obj.occupied.dynamics = true;
                obj.updateDynamics();
            end
            M = obj.M;
        end

        function C = get.C(obj)
            if(~obj.occupied.dynamics)
                obj.createMassInertiaMatrix();
                obj.occupied.dynamics = true;
                obj.updateDynamics();
            end
            C = obj.C;
        end

        function G = get.G(obj)
            if(~obj.occupied.dynamics)
                obj.createMassInertiaMatrix();
                obj.occupied.dynamics = true;
                obj.updateDynamics();
            end
            G = obj.G;
        end

        function W_grad = get.W_grad(obj)
%             if(~obj.occupied.hessian)
%                 obj.occupied.hessian = true;
%                 obj.updateHessian();
%             end
            W_grad = obj.W_grad;
        end

        function Minv_grad = get.Minv_grad(obj)
            if(~obj.occupied.linearisation)
                obj.occupied.linearisation = true;
                obj.updateLinearisation();
            end
            Minv_grad = obj.Minv_grad;
        end

        function C_grad_q = get.C_grad_q(obj)
            if(~obj.occupied.linearisation)
                obj.occupied.linearisation = true;
                obj.updateLinearisation();
            end
            C_grad_q = obj.C_grad_q;
        end

        function C_grad_qdot = get.C_grad_qdot(obj)
            if(~obj.occupied.linearisation)
                obj.occupied.linearisation = true;
                obj.updateLinearisation();
            end
            C_grad_qdot = obj.C_grad_qdot;
        end

        function G_grad = get.G_grad(obj)
            if(~obj.occupied.linearisation)
                obj.occupied.linearisation = true;
                obj.updateLinearisation();
            end
            G_grad = obj.G_grad;
        end
                
        function set.tau(obj, value)
            assert(length(value) == obj.numDofsActuated, 'Cannot set tau since the value does not match the actuated DoFs');
            count = 0;
            for k = 1:obj.numLinks
                if (obj.bodies{k}.joint.isActuated)
                    num_dofs = obj.bodies{k}.joint.numDofs;
                    obj.bodies{k}.joint.tau = value(count+1:count+num_dofs);
                    count = count + num_dofs;
                end
            end
        end
        
        function val = get.tau(obj)
            val = zeros(obj.numDofs, 1);
            count = 0;
            for k = 1:obj.numLinks
                if (obj.bodies{k}.joint.isActuated)
                    num_dofs = obj.bodies{k}.joint.numDofs;
                    val(count+1:count+num_dofs) = obj.bodies{k}.joint.tau;
                    count = count + num_dofs;
                end
            end
        end
        
        function val = get.tauMin(obj)
            val = zeros(obj.numDofsActuated, 1);
            count = 0;
            for k = 1:obj.numLinks
                if (obj.bodies{k}.joint.isActuated)
                    num_dofs = obj.bodies{k}.joint.numDofs;
                    val(count+1:count+num_dofs) = obj.bodies{k}.joint.tau_min;
                    count = count + num_dofs;
                end
            end
        end
        
        function val = get.tauMax(obj)
            val = zeros(obj.numDofsActuated, 1);
            count = 0;
            for k = 1:obj.numLinks
                if (obj.bodies{k}.joint.isActuated)
                    num_dofs = obj.bodies{k}.joint.numDofs;
                    val(count+1:count+num_dofs) = obj.bodies{k}.joint.tau_max;
                    count = count + num_dofs;
                end
            end
        end
        
        function value = get.TAU_INVALID(obj)
            value = JointBase.INVALID_TAU * ones(obj.numDofsActuated, 1);
        end
        
        function jointsNumDofVars = get.jointsNumDofVars(obj)
            jointsNumDofVars = zeros(obj.numLinks,1);
            for k = 1:obj.numLinks
                jointsNumDofVars(k) = obj.bodies{k}.numDofVars;
            end
        end
        
        function jointsNumDofs = get.jointsNumDofs(obj)
            jointsNumDofs = zeros(obj.numLinks,1);
            for k = 1:obj.numLinks
                jointsNumDofs(k) = obj.bodies{k}.numDofs;
            end
        end
    end

    methods (Access = private)
        % Generate the internal SKARot matrix for hessian and linearisation
        % computation.
        function S_KA = generate_SKA_rot(obj,k,a)
            if(a==0)
                R_a0 = eye(3);
            else
                R_a0 = obj.bodies{a}.R_0k.';
            end
            S_KA = MatrixOperations.Initialise([3,obj.index_k(k)+obj.bodies{k}.numDofs-1],obj.is_symbolic);
            if((k==0)||(a==0)||obj.bodiesPathGraph(a,k)||obj.bodiesPathGraph(k,a))
                % The bodies are connected
                if(a<=k)
                    for i =a+1:k
                        if(obj.bodiesPathGraph(i,k))
                            body_i = obj.bodies{i};
                            S_KA(:,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1) = -R_a0*body_i.R_0k*obj.S(6*i-2:6*i,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1);
                        end
                    end
                else
                    for i =k+1:a
                        if(obj.bodiesPathGraph(i,a))
                            body_i = obj.bodies{i};
                            S_KA(:,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1) = R_a0*body_i.R_0k*obj.S(6*i-2:6*i,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1);
                        end
                    end
                end
            end
        end
        
        % Generate the internal SKACrossRot matrix for hessian and linearisation
        % computation.
        function S_K = generate_SKA_cross_rot(obj,k,a)
            body_a = obj.bodies{a};
            body_k = obj.bodies{k};
            R_a0 = body_a.R_0k.';
            R_k0 = body_k.R_0k.';
            S_K = MatrixOperations.Initialise([3,obj.index_k(k)+obj.bodies{k}.numDofs-1],obj.is_symbolic);
            if(obj.bodiesPathGraph(a,k)||obj.bodiesPathGraph(k,a))
                for i = a+1:k
                    if((obj.bodiesPathGraph(i,a))||(obj.bodiesPathGraph(a,i)))
                        body_i = obj.bodies{i};
                        R_0i = body_i.R_0k;
                        S_K(:,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1) = -R_a0*R_0i*MatrixOperations.SkewSymmetric(-body_i.r_OP + (R_k0*R_0i).'*body_k.r_OG)*obj.S(6*i-2:6*i,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1);
                    end
                end
            end
        end

        % Generate the internal SKATrans matrix for hessian and linearisation
        % computation.
        function S_KA = generateSKATrans(obj,k,a)
            CASPR_log.Assert(k>=a,'Invalid input to generateSKATrans')
            R_a0 = obj.bodies{a}.R_0k.';
            S_KA = MatrixOperations.Initialise([3,obj.index_k(k)+obj.bodies{k}.numDofs-1],obj.is_symbolic);
            if(obj.bodiesPathGraph(a,k)||obj.bodiesPathGraph(k,a))
                for i =a+1:k
                    if(obj.bodiesPathGraph(i,a)||(obj.bodiesPathGraph(a,i)))
                        body_ip = obj.bodies{obj.bodies{i}.parentLinkId};
                        body_i = obj.bodies{i};
                        S_KA(:,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1) = R_a0*body_ip.R_0k*obj.S(6*i-5:6*i-3,obj.index_k(i):obj.index_k(i)+body_i.numDofs-1);
                    end
                end
            end
        end

        % Generate the gradient of the angular velocity of frame k in frame
        % k.
        function [omega_grad_q,omega_grad_q_dot] = generate_omega_grad(obj,k)
            % This generates the gradient matrix (in terms of q) associated with the
            % absolute velocity

            % Gradient with respect to q
            temp_tensor     =   MatrixOperations.Initialise([3,obj.numDofs,obj.numDofs],obj.is_symbolic);
            if(k~=0)
                body_k = obj.bodies{k};
                for a = 1:k
                    if(obj.bodiesPathGraph(a,k)||(obj.bodiesPathGraph(a,k)))
                        body_a = obj.bodies{a};
                        R_ka    = body_k.R_0k.'*body_a.R_0k;
                        % Grad(R)S
                        R_ka_grad = MatrixOperations.Initialise([3,3,obj.numDofs],obj.is_symbolic);
                        R_ka_grad(:,:,:) = obj.compute_Rka_grad(k,a);
                        temp_tensor(:,obj.index_k(a):obj.index_k(a)+obj.bodies{a}.numDofs-1,:) = temp_tensor(:,obj.index_k(a):obj.index_k(a)+obj.bodies{a}.numDofs-1,:) + ...
                            TensorOperations.RightMatrixProduct(R_ka_grad,body_a.joint.S(4:6,:),obj.is_symbolic);
                        % Grad(R)S
                        temp_tensor(:,obj.index_k(a):obj.index_k(a)+obj.bodies{a}.numDofs-1,obj.index_k(a):obj.index_k(a)+obj.bodies{a}.numDofs-1) = temp_tensor(:,obj.index_k(a):obj.index_k(a)+obj.bodies{a}.numDofs-1,obj.index_k(a):obj.index_k(a)+obj.bodies{a}.numDofs-1) + ...
                            TensorOperations.LeftMatrixProduct(R_ka,body_a.joint.S_grad(4:6,:,:),obj.is_symbolic);
                    end
                end
                omega_grad_q = TensorOperations.VectorProduct(temp_tensor,obj.q_dot,2,obj.is_symbolic);
                % Double check this
                % Gradient with respect to qdot
                omega_grad_q_dot = MatrixOperations.Initialise([3,obj.numDofs],obj.is_symbolic);
                for i = 1:k
                    if(obj.bodiesPathGraph(i,k)||obj.bodiesPathGraph(k,i))
                        R_ki = obj.bodies{k}.R_0k.'*obj.bodies{i}.R_0k;
                        omega_grad_q_dot(:,obj.index_k(i):obj.index_k(i)+obj.bodies{i}.numDofs-1) = R_ki*obj.S(6*i-2:6*i,obj.index_k(i):obj.index_k(i)+obj.bodies{i}.numDofs-1);
                    end
                end
            else
                omega_grad_q = temp_tensor;
                omega_grad_q_dot = temp_tensor;
            end
        end

        % Compute the gradient of R_ka
        function R_ka_grad = compute_Rka_grad(obj,k,a)
            % Check that this is not needed in practice
            R_ka_grad = MatrixOperations.Initialise([3,3,obj.numDofs],obj.is_symbolic);
            if(a==0)
                R_ka    = obj.bodies{k}.R_0k.';
            else
                R_ka    = obj.bodies{k}.R_0k.'*obj.bodies{a}.R_0k;
            end
            S_KAr = obj.generate_SKA_rot(k,a);
            for i = 1:size(S_KAr,2)
                R_ka_grad(:,:,i) = R_ka*MatrixOperations.SkewSymmetric(S_KAr(:,i));
            end
        end

        % Compute the gradient of P_ka
        function P_ka_grad = compute_Pka_grad(obj,k,a)
            P_ka_grad = MatrixOperations.Initialise([6,6,obj.numDofs],obj.is_symbolic);
            if(obj.bodiesPathGraph(a,k))
                % Initiailisation
                body_k = obj.bodies{k};
                body_a = obj.bodies{a};
                ap = body_a.parentLinkId;
                

                % Computation
                % TOP LEFT
                P_ka_grad(1:3,1:3,:) = obj.compute_Rka_grad(k,ap);

                % TOP RIGHT
                % This makes use of the product rule
                % First the rotation gradient term
                R_ka    = body_k.R_0k.'*body_a.R_0k;
                R_ka_grad = obj.compute_Rka_grad(k,a);
                temp_grad = MatrixOperations.Initialise([3,3,obj.numDofs],obj.is_symbolic);
                temp_grad(:,:,:) = R_ka_grad;
                P_ka_grad(1:3,4:6,:) = P_ka_grad(1:3,4:6,:) - TensorOperations.RightMatrixProduct(temp_grad,MatrixOperations.SkewSymmetric(-body_a.r_OP + R_ka.'*body_k.r_OG),obj.is_symbolic);
                    
                % Then the skew symettric matrix gradient term
                % Within this start with the relative translation
                temp_grad = MatrixOperations.Initialise([3,3,obj.numDofs],obj.is_symbolic);
                S_KAt  = obj.generateSKATrans(k,a);
                for i = 1:size(S_KAt,2)
                    temp_grad(:,:,i) = MatrixOperations.SkewSymmetric(S_KAt(:,i));
                end
                % S associated with relative rotation in the cross
                % product
                S_KAc  = obj.generate_SKA_cross_rot(k,a);
                for i = 1:size(S_KAc,2)
                    temp_grad(:,:,i) = temp_grad(:,:,i) + MatrixOperations.SkewSymmetric(S_KAc(:,i));
                end
                P_ka_grad(1:3,4:6,:) = P_ka_grad(1:3,4:6,:) - TensorOperations.LeftMatrixProduct(R_ka,temp_grad,obj.is_symbolic);

                % BOTTOM RIGHT
                P_ka_grad(4:6,4:6,:) = R_ka_grad;
            end
        end
    end

    methods (Static)
        % Load the bodies xml object.
        function b = LoadXmlObj(body_prop_xmlobj)
            % Load the body
            CASPR_log.Assert(strcmp(body_prop_xmlobj.getNodeName, 'links'), 'Root element should be <links>');

            allLinkItems = body_prop_xmlobj.getElementsByTagName('link_rigid');

            num_links = allLinkItems.getLength;
            links = cell(1,num_links);

            % Creates all of the links first
            for k = 1:num_links
                % Java uses 0 indexing
                currentLinkItem = allLinkItems.item(k-1);

                num_k = str2double(currentLinkItem.getAttribute('num'));
                CASPR_log.Assert(num_k == k, sprintf('Link number does not correspond to its order, order: %d, specified num: %d ', k, num_k));

                type = char(currentLinkItem.getNodeName);
                if (strcmp(type, 'link_rigid'))
                    links{k} = BodyModelRigid.LoadXmlObj(currentLinkItem);
                else
                    CASPRLogLevel.Print(sprintf('Unknown link type: %s', type),CASPRLogLevel.ERROR);
                end
            end

            % Create the actual object to return
            b = SystemModelBodies(links);
        end
    end
end
