import UIKit
import GRDB

class PlayersViewController: UITableViewController {
    enum PlayerOrdering {
        case byName
        case byScore
        
        var request: QueryInterfaceRequest<Player> {
            switch self {
            case .byName:
                return Player.order(Player.Columns.name)
            case .byScore:
                return Player.order(Player.Columns.score.desc, Player.Columns.name)
            }
        }
    }
    
    var playersController: FetchedRecordsController<Player>!
    var playerOrdering: PlayerOrdering = .byScore {
        didSet {
            try! playersController.setRequest(playerOrdering.request)
            configureNavigationItem()
        }
    }
    
    @IBOutlet weak var newPlayerButtonItem: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureToolbar()
        configureNavigationItem()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
}


// MARK: - Navigation

extension PlayersViewController : PlayerEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Edit" {
            let player = playersController.record(at: tableView.indexPathForSelectedRow!)
            let controller = segue.destination as! PlayerEditionViewController
            controller.title = player.name
            controller.player = player
            controller.delegate = self // See playerEditionControllerDidComplete
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "New" {
            setEditing(false, animated: true)
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.viewControllers.first as! PlayerEditionViewController
            controller.title = "New Player"
            controller.player = Player(id: nil, name: "", score: 0)
        }
    }
    
    @IBAction func cancelPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation: cancel button was tapped
    }
    
    @IBAction func commitPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation: commit button was tapped
        let controller = segue.source as! PlayerEditionViewController
        try! dbQueue.write { db in
            try controller.player.save(db)
        }
    }
    
    func playerEditionControllerDidComplete(_ controller: PlayerEditionViewController) {
        // Player edition: user has finished editing the player
        try! dbQueue.write { db in
            try controller.player.save(db)
        }
    }
}


// MARK: - UITableViewDataSource

extension PlayersViewController {
    private func configureTableView() {
        playersController = try! FetchedRecordsController(dbQueue, request: playerOrdering.request)
        
        playersController.trackChanges(
            willChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            onChange: { [unowned self] (controller, record, change) in
                switch change {
                case .insertion(let indexPath):
                    self.tableView.insertRows(at: [indexPath], with: .fade)
                    
                case .deletion(let indexPath):
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                case .update(let indexPath, _):
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        self.configure(cell, at: indexPath)
                    }
                    
                case .move(let indexPath, let newIndexPath, _):
                    // Actually move cells around for more demo effect :-)
                    let cell = self.tableView.cellForRow(at: indexPath)
                    self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    if let cell = cell {
                        self.configure(cell, at: newIndexPath)
                    }
                    
                    // A quieter animation:
                    // self.tableView.deleteRows(at: [indexPath], with: .fade)
                    // self.tableView.insertRows(at: [newIndexPath], with: .fade)
                }
            },
            didChange: { [unowned self] _ in
                self.tableView.endUpdates()
        })
        
        try! playersController.performFetch()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return playersController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playersController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        let player = playersController.record(at: indexPath)
        try! dbQueue.write { db in
            _ = try player.delete(db)
        }
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = playersController.record(at: indexPath)
        if player.name.isEmpty {
            cell.textLabel?.text = "(anonymous)"
        } else {
            cell.textLabel?.text = player.name
        }
        cell.detailTextLabel?.text = abs(player.score) > 1 ? "\(player.score) points" : "0 point"
    }
}


// MARK: - Actions

extension PlayersViewController {
    private func configureNavigationItem() {
        navigationItem.leftBarButtonItems = [editButtonItem, newPlayerButtonItem]
        
        switch playerOrdering {
        case .byScore:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Score ⬇︎",
                style: .plain,
                target: self, action: #selector(sortByName))
        case .byName:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Name ⬆︎",
                style: .plain,
                target: self, action: #selector(sortByScore))
        }
    }
    
    private func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlayers)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    @IBAction func sortByName() {
        setEditing(false, animated: true)
        playerOrdering = .byName
    }
    
    @IBAction func sortByScore() {
        setEditing(false, animated: true)
        playerOrdering = .byScore
    }
    
    @IBAction func deletePlayers() {
        setEditing(false, animated: true)
        try! dbQueue.write { db in
            _ = try Player.deleteAll(db)
        }
    }
    
    @IBAction func refresh() {
        setEditing(false, animated: true)
        refreshPlayers()
    }
    
    @IBAction func stressTest() {
        setEditing(false, animated: true)
        for _ in 0..<50 {
            DispatchQueue.global().async {
                self.refreshPlayers()
            }
        }
    }
    
    private func refreshPlayers() {
        try! dbQueue.write { db in
            if try Player.fetchCount(db) == 0 {
                // Insert new random players
                for _ in 0..<8 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
            } else {
                // Insert a player
                if arc4random_uniform(2) == 0 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
                // Delete a random player
                if arc4random_uniform(2) == 0 {
                    try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some players
                for var player in try Player.fetchAll(db) where arc4random_uniform(2) == 0 {
                    player.score = Player.randomScore()
                    try player.update(db)
                }
            }
        }
    }
}
