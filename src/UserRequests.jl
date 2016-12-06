"""
Allows for the creation of settings that will be determined
by user input.
"""
module UserRequests
export UserNumber, UserSelect, request_input

type UserNumber
    name::AbstractString
    order::Float64
end
UserNumber(name;order=Inf) = UserNumber(name,order)

type UserSelect
    name::AbstractString
    values::Array{AbstractString,1}
    order::Float64
end
UserSelect(name,values;order=Inf) = UserSelect(name,values,order)

isrequest(x) = false
isrequest(x::UserSelect) = true
isrequest(x::UserNumber) = true

function user_requests_helper(settings::SettingsParent)
    requests = map(keys(settings.assignments)) do key
        key => get(settings,key,nothing)
    end |> filter(x -> x.second == nothing)
    requests
end

function user_requests_helper(settings::SettingsChild)
    requests = map(keys(settings.assignments)) do key
        key => get(settings,key,nothing)
    end |> filter(x -> x.second == nothing)

    [requests; collect_user_requests(settings.parent)]
end

function user_requests(settings)
    OrderedDict(sort(user_requests_helper(settings),by = x->x.second.order)...)
end

function request_input(settings)
    for (key, request) = user_requests(settings)
        settings[key] = query(request)
    end
end

## TODO: run this by calling an electron program
function query(request::UserNumber)
    ## TODO: create a user interface for inputting a number
end

function query(request::UserSelect)
    ## TODO: create a user interface for select a value
end
