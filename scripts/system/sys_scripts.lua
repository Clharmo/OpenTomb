
-- gameplay globals

TR_I                = 0;
TR_I_DEMO           = 1;
TR_I_UB             = 2;
TR_II               = 3;
TR_II_DEMO          = 4;
TR_III              = 5;
TR_IV               = 6;
TR_IV_DEMO          = 7;
TR_V                = 8;
TR_UNKNOWN          = 127;

ENTITY_STATE_ENABLED                      = 0x0001;
ENTITY_STATE_ACTIVE                       = 0x0002;
ENTITY_STATE_VISIBLE                      = 0x0004;

ENTITY_TYPE_DECORATION                    = 0x0000;
ENTITY_TYPE_TRIGGER                       = 0x0001;
ENTITY_TYPE_TRIGGER_ACTIVATOR             = 0x0002;
ENTITY_TYPE_PICKABLE                      = 0x0004;
ENTITY_TYPE_TRAVERSE                      = 0x0008;
ENTITY_TYPE_TRAVERSE_FLOOR                = 0x0010;

ENTITY_CALLBACK_NONE                      = 0x00000000;
ENTITY_CALLBACK_ACTIVATE                  = 0x00000001;
ENTITY_CALLBACK_COLLISION                 = 0x00000002;
ENTITY_CALLBACK_ON_STAND                  = 0x00000004;
ENTITY_CALLBACK_ON_HIT                    = 0x00000008;

-- global frame time var, in seconds
frame_time = 1.0 / 60.0;

-- task manager
-- task struct: {functions array}
engine_tasks = {};

function addTask(f)
    local i = 0;
    while(engine_tasks[i] ~= nil) do
        i = i + 1;          -- hallow borland pascal =) It was a good time
    end
    engine_tasks[i] = f;
end

function doTasks()
    local i = 0;
    while(engine_tasks[i] ~= nil) do
        local t = engine_tasks[i]();
        if(t == false or t == nil) then
            local j = i;
            while(engine_tasks[j] ~= nil) do
                engine_tasks[j] = engine_tasks[j + 1];
                j = j + 1;
            end
        end
        i = i + 1;
    end
end

function clearTasks()
    local i = 0;
    while(engine_tasks[i] ~= nil) do
        engine_tasks[i] = nil;
        i = i + 1;
    end
end

-- timer test function
function tt()
    local t = 0.0;          -- we can store time only here
    addTask(
    function()
        if(t < 8.0) then
            t = t + frame_time;
            print(t);
            return true;
        end
        print("8 seconds complete!");
    end);
end

dofile("scripts/entity/door_script.lua");
dofile("scripts/entity/switch_script.lua");

dofile("scripts/gameflow/gameflow.lua");

--
entity_funcs = {};

-- doors - door id's to open; func - additional things we want to do after activation
function create_keyhole_func(id, doors, func, mask)
    setEntityFlags(id, nil, ENTITY_TYPE_TRIGGER);
    if(entity_funcs[id] == nil) then
        entity_funcs[id] = {};
    end

    setEntityActivity(id, 0);
    for k, v in ipairs(doors) do
        setEntityActivity(v, 0);
    end

    entity_funcs[id].onActivate = function(object_id, activator_id)
        -- canTriggerEntity(activator_id, object_id, max_dist, offset_x, offset_y, offset_z), and see magick 256.0 OY offset
        if(object_id == nil or getEntityActivity(object_id) >= 1 or canTriggerEntity(activator_id, object_id, 256.0, 0.0, 256.0, 0.0) ~= 1) then
            return;
        end

        if(getEntityActivity(object_id) == 0) then
            setEntityPos(activator_id, getEntityPos(object_id));
            moveEntityLocal(activator_id, 0.0, 256.0, 0.0);
            --
            trigger_activate(object_id, activator_id,
            function(state)
                for k, v in ipairs(doors) do
                    door_activate(v, mask);
                    setEntityActivity(v, 1);
                end
                if(func ~= nil) then
                    func();
                end
            end);
        end
    end;
end

-- standard switch function generator
-- switch: 0 - disabled
-- switch: 1 - enabled
-- switch: 2 - enable
-- switch: 3 - disable
function create_switch_func(id, doors, func, mask)
    setEntityFlags(id, nil, ENTITY_TYPE_TRIGGER);
    if(entity_funcs[id] == nil) then
        entity_funcs[id] = {};
    end

    entity_funcs[id].onActivate = function(object_id, activator_id)
        -- canTriggerEntity(activator_id, object_id, max_dist, offset_x, offset_y, offset_z)
        if(object_id == nil or canTriggerEntity(activator_id, object_id, 256.0, 0.0, 256.0, 0.0) ~= 1) then
            return;
        end

        setEntityPos(activator_id, getEntityPos(object_id));
        moveEntityLocal(activator_id, 0.0, 256.0, 0.0);
        trigger_activate(object_id, activator_id, function(state)
            for k, v in ipairs(doors) do
                door_activate(v, mask);
                setEntityActivity(v, 1);
            end
            if(func ~= nil) then
                func();
            end
        end);
    end;
end

function create_pickup_func(id, item_id)
    setEntityFlags(id, nil, ENTITY_TYPE_PICKABLE);
    if(entity_funcs[id] == nil) then
        entity_funcs[id] = {};
    end

    entity_funcs[id].onActivate = function(object_id, activator_id)
        if((item_id == nil) or (object_id == nil)) then
            return;
        end

        local need_set_pos = true;
        local curr_anim = getEntityAnim(activator_id);

        if(curr_anim == 103) then               -- Stay idle
            local dx, dy, dz = getEntityVector(object_id, activator_id);
            if(dz < -256.0) then
                need_set_pos = false;
                setEntityAnim(activator_id, 425);   -- Stay pickup, test version
            else
                setEntityAnim(activator_id, 135);   -- Stay pickup
            end;
        elseif(curr_anim == 222) then           -- Crouch idle
            setEntityAnim(activator_id, 291);   -- Crouch pickup
        elseif(curr_anim == 263) then           -- Crawl idle
            setEntityAnim(activator_id, 292);   -- Crawl pickup
        elseif(curr_anim == 108) then           -- Swim idle
            setEntityAnim(activator_id, 130);   -- Swim pickup
        else
            return;     -- Disable picking up, if Lara isn't idle.
        end;

        print("you try to pick up object ".. object_id);

        local px, py, pz = getEntityPos(object_id);
        if(curr_anim == 108) then
            pz = pz + 128.0                     -- Shift offset for swim pickup.
        end;

        if(need_set_pos) then
            setEntityPos(activator_id, px, py, pz);
        end;

        addTask(
        function()
            local a, f, c = getEntityAnim(activator_id);
            local ver = getLevelVersion();

            -- Standing pickup anim makes action on frame 40 in TR1-3, in TR4-5
            -- it was generalized with all rest animations by frame 16.

            if((a == 135) and (ver < TR_IV)) then
                if(f < 40) then
                    return true;
                end;
            else
                if(f < 16) then
                    return true;
                end;
            end;

            addItem(activator_id, item_id);
            disableEntity(object_id);
        end);
    end;
end


function create_trapfloor_func(id)
    setEntityFlags(id, nil, nil, ENTITY_CALLBACK_ON_STAND);
    if(entity_funcs[id] == nil) then
        entity_funcs[id] = {};
    end

    entity_funcs[id].onStand = function(object_id, activator_id)
        if((object_id == nil) or (activator_id == nil)) then
            return;
        end

        local anim = getEntityAnim(object_id);
        if(anim == 0) then
            setEntityAnim(object_id, 1);
            print("you trapped to id = "..object_id);
            local t = 0.0;          -- we can store time only here
            addTask(
            function()
                if(t > 1.5) then
                    setEntityCollision(object_id, 0);
                end;
                if(t < 2.0) then
                    t = t + frame_time;
                    return true;
                end;
                local anim = getEntityAnim(object_id);
                if(anim == 1) then
                    setEntityAnim(object_id, 2);
                end;
                if(t < 3.0) then
                    t = t + frame_time;
                    return true;
                end;
                setEntityAnim(object_id, 3);
            end);
        end;
    end;
end


function create_pushdoor_func(id)
    setEntityActivity(id, 0);
    setEntityFlags(id, nil, ENTITY_TYPE_TRIGGER);
    if(entity_funcs[id] == nil) then
        entity_funcs[id] = {};
    end

    entity_funcs[id].onActivate = function(object_id, activator_id)
        if((object_id == nil) or (activator_id == nil)) then
            return;
        end;

        if((getEntityActivity(object_id) == 0) and (getEntityDirDot(object_id, activator_id) < -0.9)) then
            setEntityActivity(object_id, 1);
            local x, y, z, az, ax, ay = getEntityPos(object_id);
            setEntityPos(activator_id, x, y, z, az + 180.0, ax, ay);
            moveEntityLocal(activator_id, 0.0, 256.0, 0.0);
            -- floor door 317 anim
            -- vertical door 412 anim
            setEntityAnim(activator_id, 412);
        end;
    end;
end

function activateEntity(object_id, activator_id, callback_id)
    --print("try to activate "..object_id.." by "..activator_id)
    if((activator_id == nil) or (object_id == nil) or (callback_id == nil)) then
        return;
    end

    if(entity_funcs[object_id] ~= nil) then
        if((bit32.band(callback_id, ENTITY_CALLBACK_ACTIVATE) ~= 0) and (entity_funcs[object_id].onActivate ~= nil)) then
            entity_funcs[object_id].onActivate(object_id, activator_id);
        end;

        if((bit32.band(callback_id, ENTITY_CALLBACK_COLLISION) ~= 0) and (entity_funcs[object_id].onCollide ~= nil)) then
            entity_funcs[object_id].onCollide(object_id, activator_id);
        end;

        if((bit32.band(callback_id, ENTITY_CALLBACK_ON_STAND) ~= 0) and (entity_funcs[object_id].onStand ~= nil)) then
            entity_funcs[object_id].onStand(object_id, activator_id);
        end;

        if((bit32.band(callback_id, ENTITY_CALLBACK_ON_HIT) ~= 0) and (entity_funcs[object_id].onHit ~= nil)) then
            entity_funcs[object_id].onHit(object_id, activator_id);
        end;
    end;
end

print("system_scripts.lua loaded");
