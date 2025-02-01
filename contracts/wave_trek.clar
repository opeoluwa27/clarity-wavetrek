;; WaveTrek - Social Audio Platform Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-track-exists (err u101))
(define-constant err-no-track (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-playlist-exists (err u104))
(define-constant err-no-playlist (err u105))

;; Data Variables
(define-data-var platform-fee uint u50) ;; 5% in basis points
(define-data-var next-playlist-id uint u1)

;; Data Maps
(define-map tracks 
    {track-id: uint} 
    {
        creator: principal,
        title: (string-utf8 100),
        ipfs-hash: (string-utf8 100),
        remix-enabled: bool,
        remix-fee: uint,
        original-track: (optional uint),
        play-count: uint,
        like-count: uint
    }
)

(define-map creator-profiles
    principal
    {
        name: (string-utf8 50),
        bio: (string-utf8 500),
        followers: uint
    }
)

(define-map following
    {follower: principal, creator: principal}
    {timestamp: uint}
)

(define-map playlists
    {playlist-id: uint}
    {
        creator: principal,
        name: (string-utf8 100),
        description: (string-utf8 500),
        tracks: (list 100 uint),
        is-public: bool
    }
)

(define-map track-likes
    {user: principal, track-id: uint}
    {timestamp: uint}
)

;; Track Management
(define-public (upload-track 
    (track-id uint) 
    (title (string-utf8 100))
    (ipfs-hash (string-utf8 100))
    (remix-enabled bool)
    (remix-fee uint))
    (let ((track-exists (get creator (map-get? tracks {track-id: track-id}))))
        (if (is-some track-exists)
            err-track-exists
            (begin
                (map-set tracks 
                    {track-id: track-id}
                    {
                        creator: tx-sender,
                        title: title,
                        ipfs-hash: ipfs-hash,
                        remix-enabled: remix-enabled,
                        remix-fee: remix-fee,
                        original-track: none,
                        play-count: u0,
                        like-count: u0
                    }
                )
                (ok true)
            )
        )
    )
)

(define-public (create-remix
    (new-track-id uint)
    (original-track-id uint)
    (title (string-utf8 100))
    (ipfs-hash (string-utf8 100)))
    (let (
        (original (map-get? tracks {track-id: original-track-id}))
    )
        (match original original-track
            (if (and 
                    (get remix-enabled original-track)
                    (map-insert tracks
                        {track-id: new-track-id}
                        {
                            creator: tx-sender,
                            title: title,
                            ipfs-hash: ipfs-hash,
                            remix-enabled: false,
                            remix-fee: u0,
                            original-track: (some original-track-id),
                            play-count: u0,
                            like-count: u0
                        }
                    ))
                (ok true)
                err-unauthorized
            )
            err-no-track
        )
    )
)

;; Playlist Management
(define-public (create-playlist 
    (name (string-utf8 100))
    (description (string-utf8 500))
    (is-public bool))
    (let ((playlist-id (var-get next-playlist-id)))
        (map-insert playlists
            {playlist-id: playlist-id}
            {
                creator: tx-sender,
                name: name,
                description: description,
                tracks: (list),
                is-public: is-public
            }
        )
        (var-set next-playlist-id (+ playlist-id u1))
        (ok playlist-id)
    )
)

(define-public (add-track-to-playlist 
    (playlist-id uint)
    (track-id uint))
    (let (
        (playlist (map-get? playlists {playlist-id: playlist-id}))
        (track (map-get? tracks {track-id: track-id}))
    )
        (match playlist existing-playlist
            (if (and
                    (is-eq tx-sender (get creator existing-playlist))
                    (is-some track)
                )
                (begin
                    (map-set playlists
                        {playlist-id: playlist-id}
                        (merge existing-playlist 
                            {tracks: (unwrap-panic (as-max-len? 
                                (append (get tracks existing-playlist) track-id)
                                u100
                            ))}
                        )
                    )
                    (ok true)
                )
                err-unauthorized
            )
            err-no-playlist
        )
    )
)

;; Track Interactions
(define-public (like-track (track-id uint))
    (let ((track (map-get? tracks {track-id: track-id})))
        (match track existing-track
            (begin
                (map-set track-likes
                    {user: tx-sender, track-id: track-id}
                    {timestamp: block-height}
                )
                (map-set tracks
                    {track-id: track-id}
                    (merge existing-track
                        {like-count: (+ (get like-count existing-track) u1)}
                    )
                )
                (ok true)
            )
            err-no-track
        )
    )
)

(define-public (record-play (track-id uint))
    (let ((track (map-get? tracks {track-id: track-id})))
        (match track existing-track
            (begin
                (map-set tracks
                    {track-id: track-id}
                    (merge existing-track
                        {play-count: (+ (get play-count existing-track) u1)}
                    )
                )
                (ok true)
            )
            err-no-track
        )
    )
)

;; Social Functions
(define-public (follow-creator (creator principal))
    (begin
        (map-set following
            {follower: tx-sender, creator: creator}
            {timestamp: block-height}
        )
        (let ((profile (map-get? creator-profiles creator)))
            (match profile existing-profile
                (map-set creator-profiles
                    creator
                    (merge existing-profile {followers: (+ (get followers existing-profile) u1)})
                )
                (map-set creator-profiles
                    creator
                    {name: "", bio: "", followers: u1}
                )
            )
        )
        (ok true)
    )
)

(define-public (update-profile 
    (name (string-utf8 50))
    (bio (string-utf8 500)))
    (begin
        (map-set creator-profiles
            tx-sender
            {
                name: name,
                bio: bio,
                followers: (default-to u0 (get followers (map-get? creator-profiles tx-sender)))
            }
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-track-info (track-id uint))
    (ok (map-get? tracks {track-id: track-id}))
)

(define-read-only (get-creator-profile (creator principal))
    (ok (map-get? creator-profiles creator))
)

(define-read-only (is-following (follower principal) (creator principal))
    (ok (is-some (map-get? following {follower: follower, creator: creator})))
)

(define-read-only (get-playlist (playlist-id uint))
    (ok (map-get? playlists {playlist-id: playlist-id}))
)

(define-read-only (has-liked-track (user principal) (track-id uint))
    (ok (is-some (map-get? track-likes {user: user, track-id: track-id})))
)
