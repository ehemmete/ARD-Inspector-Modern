import Foundation

struct ARDComputer: Identifiable, Hashable {
    let id: String // UUID
    let name: String
    let osVersion: String?
    let hardwareAddress: String?
    let machineSerialNumber: String?
    let networkAddress: String?
    let hostname: String?
    let login: String?
    let password: String?
    
    init(dict: [String: Any]) {
        // Use a more robust way to get the UUID
        if let uuid = dict["uuid"] as? String {
            self.id = uuid
        } else if let uuid = dict["uuid"] {
            self.id = "\(uuid)"
        } else {
            self.id = "Unknown"
        }
        
        self.name = dict["name"] as? String ?? "Unknown"
        self.osVersion = dict["OSVersion"] as? String
        self.hardwareAddress = dict["hardwareAddress"] as? String
        self.machineSerialNumber = dict["machineSerialNumber"] as? String
        self.networkAddress = dict["networkAddress"] as? String
        self.hostname = dict["hostname"] as? String
        self.login = nil // Set later from credentials
        self.password = nil // Set later from credentials
    }
    
    func updatingCredentials(login: String?, password: String?) -> ARDComputer {
        return ARDComputer(
            id: id,
            name: name,
            osVersion: osVersion,
            hardwareAddress: hardwareAddress,
            machineSerialNumber: machineSerialNumber,
            networkAddress: networkAddress,
            hostname: hostname,
            login: login,
            password: password
        )
    }
    
    init(id: String, name: String, osVersion: String?, hardwareAddress: String?, machineSerialNumber: String?, networkAddress: String?, hostname: String?, login: String?, password: String?) {
        self.id = id
        self.name = name
        self.osVersion = osVersion
        self.hardwareAddress = hardwareAddress
        self.machineSerialNumber = machineSerialNumber
        self.networkAddress = networkAddress
        self.hostname = hostname
        self.login = login
        self.password = password
    }
}

enum ARDItem: Identifiable, Hashable {
    case computer(ARDComputer)
    case list(ARDList)
    case folder(ARDFolder)
    
    var id: String {
        switch self {
        case .computer(let c): return c.id
        case .list(let l): return l.id
        case .folder(let f): return f.id
        }
    }
    
    var name: String {
        switch self {
        case .computer(let c): return c.name
        case .list(let l): return l.name
        case .folder(let f): return f.name
        }
    }
}

struct ARDList: Identifiable, Hashable {
    let id: String
    let name: String
    let members: [String] // UUIDs
}

struct ARDFolder: Identifiable, Hashable {
    let id: String
    let name: String
    let members: [String] // UUIDs (can be lists or other folders)
}
