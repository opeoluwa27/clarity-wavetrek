import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can upload new track",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('wave-trek', 'upload-track', [
                types.uint(1),
                types.utf8("My First Track"),
                types.utf8("QmHash123"),
                types.bool(true),
                types.uint(100)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        let trackInfo = chain.callReadOnlyFn(
            'wave-trek',
            'get-track-info',
            [types.uint(1)],
            deployer.address
        );
        
        trackInfo.result.expectOk().expectSome();
    }
});

Clarinet.test({
    name: "Can create and manage playlists",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Create playlist
        let block = chain.mineBlock([
            Tx.contractCall('wave-trek', 'create-playlist', [
                types.utf8("My Playlist"),
                types.utf8("Cool tracks"),
                types.bool(true)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        
        // Upload track
        chain.mineBlock([
            Tx.contractCall('wave-trek', 'upload-track', [
                types.uint(1),
                types.utf8("Track 1"),
                types.utf8("QmHash123"),
                types.bool(true),
                types.uint(100)
            ], deployer.address)
        ]);
        
        // Add track to playlist
        let addTrackBlock = chain.mineBlock([
            Tx.contractCall('wave-trek', 'add-track-to-playlist', [
                types.uint(1),
                types.uint(1)
            ], deployer.address)
        ]);
        
        assertEquals(addTrackBlock.receipts[0].result.expectOk(), true);
    }
});

Clarinet.test({
    name: "Can interact with tracks through likes and plays",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user = accounts.get('wallet_1')!;
        
        // Upload track
        chain.mineBlock([
            Tx.contractCall('wave-trek', 'upload-track', [
                types.uint(1),
                types.utf8("Track 1"),
                types.utf8("QmHash123"),
                types.bool(true),
                types.uint(100)
            ], deployer.address)
        ]);
        
        // Like track
        let likeBlock = chain.mineBlock([
            Tx.contractCall('wave-trek', 'like-track', [
                types.uint(1)
            ], user.address)
        ]);
        
        assertEquals(likeBlock.receipts[0].result.expectOk(), true);
        
        // Record play
        let playBlock = chain.mineBlock([
            Tx.contractCall('wave-trek', 'record-play', [
                types.uint(1)
            ], user.address)
        ]);
        
        assertEquals(playBlock.receipts[0].result.expectOk(), true);
        
        // Check like status
        let hasLiked = chain.callReadOnlyFn(
            'wave-trek',
            'has-liked-track',
            [
                types.principal(user.address),
                types.uint(1)
            ],
            user.address
        );
        
        hasLiked.result.expectOk().expectBool(true);
    }
});
