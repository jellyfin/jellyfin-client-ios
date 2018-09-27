//
//  ItemViewController.swift
//  Emby Player
//
//  Created by Mats Mollestad on 29/08/2018.
//  Copyright © 2018 Mats Mollestad. All rights reserved.
//

import UIKit


protocol SingleItemStoreFetchable {
    func fetchItem(completion: @escaping (FetcherResponse<PlayableItem>) -> Void)
}

struct SingleItemStoreEmbyFetcher: SingleItemStoreFetchable {
    
    var itemId: String
    
    func fetchItem(completion: @escaping (FetcherResponse<PlayableItem>) -> Void) {
        
        guard let server = ServerManager.currentServer else {
            completion(.failed(ServerManager.Errors.unableToConnectToServer))
            return
        }
        
        server.fetchItemWith(id: itemId) { (response) in
            completion(FetcherResponse(response: response))
        }
    }
}

class SingleItemStore {
    let fetcher: SingleItemStoreFetchable
    var item: PlayableItem?
    
    init(fetcher: SingleItemStoreFetchable) {
        self.fetcher = fetcher
    }
    
    func fetchItem(completion: @escaping (FetcherResponse<Void>) -> Void) {
        fetcher.fetchItem { [weak self] (response) in
            
            var retResponse: FetcherResponse<Void> = .success(())
            switch response {
            case .failed(let error): retResponse = .failed(error)
            case .success(let item): self?.item = item
            }
            completion(retResponse)
        }
    }
}

protocol ItemViewControllerDelegate: class {
    func playItem(_ item: PlayableItem)
    func downloadItem(_ item: PlayableItem)
}


class ItemViewController: UIViewController, ContentViewControlling {
    
    var contentViewController: UIViewController { return self }
    
    var store: SingleItemStore
    
    
    lazy var scrollView: UIScrollView = self.setUpScrollView()
    lazy var contentView: UIStackView = self.setUpContentView()
    lazy var imageView: UIImageView = self.setUpImageView()
    lazy var titleLabel: UILabel = self.setUpTitleLabel()
    lazy var playButton: UIButton = self.setUpPlayButton()
    lazy var downloadButton: UIButton = self.setUpDownloadButton()
    lazy var downloadLabel: UILabel = self.setUpDownloadLabel()
    lazy var overviewTextView: UITextView = self.setUpOverviewTextView()
    lazy var seasonLabel: UILabel = self.setUpSeasonLabel()
    lazy var durationLabel: UILabel = self.setUpQualityLabel()
    lazy var qualityLabel: UILabel = self.setUpQualityLabel()
    
    
    weak var delegate: ItemViewControllerDelegate?
    
    init(fetcher: SingleItemStoreFetchable) {
        self.store = SingleItemStore(fetcher: fetcher)
        super.init(nibName: nil, bundle: nil)
        setUpViewController()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Decoder not implemented")
    }
    
    
    func fetchContent(completion: @escaping (FetcherResponse<Void>) -> Void) {
        store.fetchItem { (response) in
            DispatchQueue.main.async { [weak self] in
                self?.updateItem()
            }
            completion(response)
        }
        store.fetchItem(completion: completion)
    }
    
    
    private func setUpViewController() {
        view.addSubview(scrollView)
        scrollView.fillSuperView()
    }
    
    
    private func updateItem() {
        
        guard let item = store.item else { return }
        title = item.name
        titleLabel.text = item.name
        overviewTextView.text = item.overview
        seasonLabel.text = (item.seriesName ?? "") + " - " + (item.seasonName ?? "")
        durationLabel.text = "Duration: " + timeString(for: Double(item.runTime) / 10000000)
        downloadLabel.isHidden = true
        
        if let videoStream = item.mediaStreams.first(where: { $0.type == "Video" }) {
            qualityLabel.text = "Video Quality: \(videoStream.displayTitle ?? ""), \(videoStream.aspectRatio ?? "")"
        }
        
        if item.diskUrlPath != nil {
            downloadButton.setTitle("You have downloaded this item", for: .normal)
            downloadButton.isEnabled = false
        }
        
        seasonLabel.isHidden = item.seriesName == nil
        overviewTextView.isHidden = item.overview == nil
        qualityLabel.isHidden = item.mediaStreams.first == nil
        imageView.isHidden = true
        
        if let imageUrl = item.imageUrl(with: .primary) {
            imageView.isHidden = false
            imageView.fetch(imageUrl) { [weak self] (_) in
                DispatchQueue.main.async {
                    self?.imageView.isHidden = true
                }
            }
        }
    }
    
    
    @objc
    private func playItem() {
        
        guard let item = store.item else { return }
        guard (item.mediaSource.first) != nil else { return }
        
        delegate?.playItem(item)
    }
    
    @objc
    private func downloadItem() {
        guard let item = store.item else { return }
        delegate?.downloadItem(item)
        
        downloadButton.isEnabled = false
        downloadButton.setTitle("Downloading", for: .normal)
        downloadLabel.text = "Download started"
        downloadLabel.isHidden = false
    }
    
    private func update(with downloadProgress: DownloadProgress) {
        DispatchQueue.main.async { [weak self] in
            self?.downloadLabel.text = "Download Progress: \(Double(Int(downloadProgress.progress*1000))/10)%"
        }
    }
    
    private func timeString(for duration: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        
        return formatter.string(from: duration) ?? ""
    }
    
    
    // MARK: - View Configs / Init
    
    private func setUpScrollView() -> UIScrollView {
        let view = UIScrollView()
        view.alwaysBounceVertical = true
        view.addSubview(contentView)
        contentView.fillSuperView()
        contentView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1).isActive = true
        return view
    }
    
    private func setUpContentView() -> UIStackView {
        let views = [imageView, titleLabel, seasonLabel, playButton, downloadButton, downloadLabel, durationLabel, qualityLabel, overviewTextView]
        let view = UIStackView(arrangedSubviews: views)
        view.axis = .vertical
        view.spacing = 10
        view.layoutMargins = UIEdgeInsets(top: 10, left: 20, bottom: 20, right: 20)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }
    
    private func setUpPlayButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Play", for: .normal)
        button.backgroundColor = .green
        button.layer.cornerRadius = 8
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.addTarget(self, action: #selector(playItem), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }
    
    private func setUpDownloadButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Download", for: .normal)
        button.backgroundColor = .orange
        button.layer.cornerRadius = 8
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.addTarget(self, action: #selector(downloadItem), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }
    
    private func setUpDownloadLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }
    
    private func setUpTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        label.textColor = .white
        return label
    }
    
    private func setUpImageView() -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 7/16).isActive = true
        return view
    }
    
    private func setUpOverviewTextView() -> UITextView {
        let view = UITextView()
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.isEditable = false
        view.font = UIFont.systemFont(ofSize: 14)
        view.textColor = .white
        return view
    }
    
    private func setUpSeasonLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        return label
    }
    
    private func setUpQualityLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = .white
        return label
    }
}


extension ItemViewController: PlayerViewControllerDelegate {
    func playerWillDisappear(_ player: PlayerViewController) {
        
        DeviceRotateManager.shared.allowedOrientations = .allButUpsideDown
        guard let item = store.item, let userId = UserManager.shared.current?.id else { return }
        let fraction = player.currentTime.seconds / player.duration.seconds
        if fraction > 0.93 {
            ServerManager.currentServer?.markItemAsWatched(item, userId: userId)
        }
    }
}

extension ItemViewController: DownloadManagerDelegate {
    
    func downloadDidUpdate(_ progress: DownloadProgress) {
        DispatchQueue.main.async { [weak self] in
            self?.downloadLabel.text = "Downloading: \((progress.progress * 1000).rounded(.down)/10)%"
        }
    }
    
    func downloadWasCompleted(_ response: FetcherResponse<String>) {
        DispatchQueue.main.async { [weak self] in
            switch response {
            case .failed(let error):
                self?.downloadLabel.text = "Ups, an error occured. This may be because the original file is unsupported\nError: \(error.localizedDescription)"
            case .success(let url):
                self?.downloadButton.setTitle("Download Completed", for: .normal)
                guard var item = self?.store.item else { return }
                print("Successfully downloaded: \(item.name)")
                do {
                    item.diskUrlPath = url
                    try PlayableOfflineManager.shared.add(item)
                } catch {
                    print("Error adding item:", error)
                }
            }
        }
    }
}