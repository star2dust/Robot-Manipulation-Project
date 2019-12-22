% Rigid Cuboid 3D Model class (3 inputs: inputMass(1x1),inputPosition(6x1),inputEdges(1x3))
% (last mod.: 20-05-2019, Author: Chu Wu)
% Requires Robotics Toolbox of Peter Corke http://petercorke.com/wordpress/toolboxes/robotics-toolbox
% Properties:
% - states: position, velocity, acceleration
% - frames: rotMat, hTransMat, hTransMat, hTransMatDot
% - dynamics parameters: mass, inertia, inerMat
% - shapes: vertices, faces, edges
% - vertices states: verticesStates
% Methods:
% - setVelocity
% - forwardDynamics
% - getStates
% - updateStates
classdef RigidCuboidOld < handle
    properties (SetAccess = protected)
        % translation & rotation states in world frame (6 dim)
        % angle expressed in Euler angle rotations "ZYX" ( R = Rz(thy)*Ry(thp)*Rx(thr))
        position
        velocity = [0,0,0,0,0,0]'
        acceleration = [0,0,0,0,0,0]'
        % frames
        rotMat
        rotMatDot = zeros(3)
        hTransMat
        hTransMatDot = blkdiag(zeros(3),1)
        % params
        mass % center of body frame (1 dim)
        inertia % [Ixx Iyy Izz -Iyz Ixz -Ixy] vector relative to the body frame (6 dim)
        % how to calculate? => I = diag([Ixx Iyy Izz])+skew([-Iyz Ixz -Ixy])
        inerMat % [M,0;0,I]
        % a list of vertices and edges in body frame
        vertices % (8x3)
        faces % (6x4)
        edges % (1x3) depth(x) width(y) height(z)
        % vertices list in world frame
        verticesStates = struct % position + velocity
    end
    
    properties (Constant, Access = private)
        templateVertices = [0,0,0;0,1,0;1,1,0;1,0,0;0,0,1;0,1,1;1,1,1;1,0,1];
        templateFaces = [1,2,3,4;5,6,7,8;1,2,6,5;3,4,8,7;1,4,8,5;2,3,7,6];
        % ^ y axis
        % | 6 % % 7 -> top
        % | % 2 3 % -> bottom
        % | % 1 4 % -> bottom
        % | 5 % % 8 -> top
        % -------> x axis
    end
    
%     properties (Transient)
%         % contactsListener property is transient so the listener handle is not saved.
%         contactsListener
%     end
%     
%     events
%         contactsOccured
%     end
    
    methods
        function obj = RigidCuboidOld(inputMass,inputPosition,inputEdges)
            import pkgMechanics.*
            % basic configuration
            if isscalar(inputMass)&&isvector(inputPosition)&&length(inputPosition)==6&&isvector(inputEdges)&&length(inputEdges)==3
                % weighted average (sum(weighList.*variableList,2)/sum(weighList))
                % parallel axis theorem (sum(weighList.*diag(variableList'*variableList)'))
                obj.position = inputPosition(:);
                obj.mass = inputMass;
                obj.inertia = 1/12*inputMass*[inputEdges(2)^2+inputEdges(3)^2 inputEdges(1)^2+inputEdges(3)^2 inputEdges(2)^2+inputEdges(1)^2 0 0 0];
                obj.inerMat = [obj.mass*eye(3),zeros(3);zeros(3),diag(obj.inertia(1:3))+skew(obj.inertia(4:end))];
                % rotation matrix
                obj.rotMat = rotz(obj.position(6))*roty(obj.position(5))*rotx(obj.position(4));
                obj.hTransMat = rt2tr(obj.rotMat,obj.position(1:3));
                % vertices list in body frame (format: [x y z])
                obj.edges = inputEdges(:)';
                obj.edge2body;
                % vertices list in world frame
                obj.verticesStates.velocity = obj.rotMatDot*obj.vertices' + obj.velocity(1:3);
                obj.verticesStates.position = obj.rotMat*obj.vertices' + obj.position(1:3);
            else
                error('Improper input dimension.')
            end
            % addition configuration
%             obj.statesListener = addlistener(obj, 'statesUpdated', @(src,~)obj.onStatesUpdated(src));
        end
        
        function obj = setVelocity(obj,inputVelocity)
            if isvector(inputVelocity)&&length(inputVelocity)==6
                % update frame velocity
                obj.velocity = inputVelocity(:);
                % if frame is changed, the vertices should also be changed
                obj.updateVerticesVelocity;
            else
                error('Improper input dimension.')
            end
        end
        
        function obj = forwardDynamics(obj,graspMat,wrenchContact,ImpMass)
            wrenchBody = graspMat*wrenchContact(:);
            if nargin==4
                obj.acceleration = (obj.inerMat+ImpMass)^-1*wrenchBody;
            else
                 obj.acceleration = obj.inerMat^-1*wrenchBody;
            end
        end
        
        function obj = updateStates(obj,cycle)
            obj.position = obj.position+obj.velocity*cycle+obj.acceleration*cycle^2/2;
            obj.velocity = obj.velocity + obj.acceleration*cycle;
            obj.verticesStates.position = obj.rotMat*obj.vertices' + obj.position(1:3);
            % velocity update (vertices)
            obj.updateVerticesVelocity;
            % frame update
            obj.rotMat = rotz(obj.position(6))*roty(obj.position(5))*rotx(obj.position(4));
            obj.hTransMat = rt2tr(obj.rotMat,obj.position(1:3));
%             % regulate angles within [0,2*pi]
%             round = floor(obj.position(4:end)/(2*pi));
%             obj.position = obj.position - [0;0;0;round]*2*pi; 
%             % after position update is finished
%             notify(obj,'statesUpdated')
        end
        
        function getStates(obj)
            import pkgMechanics.*
            disp('--------Rigid Cuboid--------')
            disp(['mass: ',num2str(obj.mass)])
            disp(['inertia: ',mat2strf(obj.inertia,'%0.2f')])
            disp(['position: ',mat2strf(obj.position,'%0.2f')])
            disp(['velocity: ',mat2strf(obj.velocity,'%0.2f')])
            disp(['acceleration: ',mat2strf(obj.acceleration,'%0.2f')])
            disp('----------------------------')
        end
    end
    
    methods (Access = protected)
%         function onStatesUpdated(eventSrc,eventData)
%             % eventSrc is just the object itself
%             % eventData(also an object) is used when you notify it (notify(obj,'statesUpdated',eventData))
%             % set rotation matrix and homogeneous transformation matrix
%             eventSrc.updateMatrices;
%             % set vertices list in world frame
%             eventSrc.updateVerticesStates;
%         end
%               
        function obj = updateVerticesVelocity(obj)
            wx = [1,0,0]'; wy = [0,1,0]'; wz = [0,0,1]';
            % matrix time derivative
            obj.rotMatDot = obj.velocity(6)*skew(wz)*rotz(obj.position(6))*roty(obj.position(5))*rotx(obj.position(4))...
                    +rotz(obj.position(6))*obj.velocity(5)*skew(wy)*roty(obj.position(5))*rotx(obj.position(4))...
                    +rotz(obj.position(6))*roty(obj.position(5))*obj.velocity(4)*skew(wx)*rotx(obj.position(4));
            obj.hTransMatDot = rt2tr(obj.rotMatDot,obj.velocity(1:3));
            % velocity
            obj.verticesStates.velocity = obj.rotMatDot*obj.vertices'+obj.velocity(1:3);
        end
        
        function obj = edge2body(obj)
           obj.faces = obj.templateFaces;
           obj.vertices = [obj.templateVertices(:,1)*obj.edges(1)-obj.edges(1)/2,obj.templateVertices(:,2)*obj.edges(2)-obj.edges(2)/2,obj.templateVertices(:,3)*obj.edges(3)-obj.edges(3)/2]; 
        end
    end
end