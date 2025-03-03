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
(define-constant err-invalid-fee (err u108))
(define-constant max-fee-basis-points u1000)
(define-constant max-tracks u1000000)

;; Data Variables
(define-data-var platform-fee uint u50) ;; 5% in basis points
(define-data-var next-track-id uint u1)
(define-data-var next-playlist-id uint u1)

;; Helper Functions
(define-private (is-valid-track-id (track-id uint))
    (match (map-get? tracks {track-id: track-id})
        track (and (is-some track) (not (get deleted (unwrap-panic track))))
        false
    )
)

(define-private (validate-ipfs-hash (ipfs-hash (string-utf8 100)))
    (and 
        (> (len ipfs-hash) u0)
        (<= (len ipfs-hash) u100)
    )
)

;; Rest of the maps remain unchanged...

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
        (asserts! (validate-ipfs-hash ipfs-hash) err-invalid-input)
        (asserts! (<= remix-fee max-fee-basis-points) err-invalid-fee)
        (asserts! (< track-id max-tracks) err-invalid-input)
        
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
        (print {event: "track-uploaded", track-id: track-id, creator: tx-sender})
        (ok track-id)
    )
)

(define-public (update-track
    (track-id uint)
    (title (string-utf8 100))
    (remix-enabled bool)
    (remix-fee uint))
    (let ((track (map-get? tracks {track-id: track-id})))
        (match track existing-track
            (begin
                (asserts! (is-eq tx-sender (get creator existing-track)) err-unauthorized)
                (asserts! (not (get deleted existing-track)) err-no-track)
                (asserts! (<= remix-fee max-fee-basis-points) err-invalid-fee)
                (asserts! (> (len title) u0) err-invalid-input)
                
                (map-set tracks
                    {track-id: track-id}
                    (merge existing-track {
                        title: title,
                        remix-enabled: remix-enabled,
                        remix-fee: remix-fee
                    })
                )
                (print {event: "track-updated", track-id: track-id})
                (ok true)
            )
            err-no-track
        )
    )
)

;; Rest of the contract remains unchanged...
