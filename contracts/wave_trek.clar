;; WaveTrek - Social Audio Platform Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-track-exists (err u101))
(define-constant err-no-track (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-playlist-exists (err u104))
(define-constant err-no-playlist (err u105))
(define-constant err-invalid-input (err u106))
(define-constant err-playlist-full (err u107))

;; Data Variables
(define-data-var platform-fee uint u50) ;; 5% in basis points
(define-data-var next-track-id uint u1)
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
        like-count: uint,
        created-at: uint,
        deleted: bool
    }
)

(define-map creator-profiles
    principal
    {
        name: (string-utf8 50),
        bio: (string-utf8 500),
        followers: uint,
        track-count: uint
    }
)

(define-map playlists
    {playlist-id: uint}
    {
        creator: principal,
        name: (string-utf8 100),
        description: (string-utf8 500),
        tracks: (list 100 uint),
        track-count: uint,
        is-public: bool
    }
)

;; Track Management
(define-public (upload-track 
    (title (string-utf8 100))
    (ipfs-hash (string-utf8 100))
    (remix-enabled bool)
    (remix-fee uint))
    (let (
        (track-id (var-get next-track-id))
        (creator-profile (default-to 
            {name: "", bio: "", followers: u0, track-count: u0} 
            (map-get? creator-profiles tx-sender)))
    )
        (asserts! (> (len title) u0) err-invalid-input)
        (asserts! (> (len ipfs-hash) u0) err-invalid-input)
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
                like-count: u0,
                created-at: block-height,
                deleted: false
            }
        )
        (map-set creator-profiles
            tx-sender
            (merge creator-profile 
                {track-count: (+ (get track-count creator-profile) u1)}
            )
        )
        (var-set next-track-id (+ track-id u1))
        (ok track-id)
    )
)

(define-public (delete-track (track-id uint))
    (let ((track (map-get? tracks {track-id: track-id})))
        (match track existing-track
            (begin
                (asserts! (is-eq tx-sender (get creator existing-track)) err-unauthorized)
                (asserts! (not (get deleted existing-track)) err-no-track)
                (map-set tracks
                    {track-id: track-id}
                    (merge existing-track {deleted: true})
                )
                (ok true)
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
        (asserts! (> (len name) u0) err-invalid-input)
        (map-insert playlists
            {playlist-id: playlist-id}
            {
                creator: tx-sender,
                name: name,
                description: description,
                tracks: (list),
                track-count: u0,
                is-public: is-public
            }
        )
        (var-set next-playlist-id (+ playlist-id u1))
        (ok playlist-id)
    )
)

;; Include rest of the original contract functions with similar improvements...
