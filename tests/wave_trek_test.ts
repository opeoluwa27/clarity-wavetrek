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
    name: "Can create remix of existing track",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const creator2 = accounts.get('wallet_1')!;
        
        // First upload original track
        chain.mineBlock([
            Tx.contractCall('wave-trek', 'upload-track', [
                types.uint(1),
                types.utf8("Original Track"),
                types.utf8("QmHash123"),
                types.bool(true),
                types.uint(100)
            ], deployer.address)
        ]);
        
        // Create remix
        let remixBlock = chain.mineBlock([
            Tx.contractCall('wave-trek', 'create-remix', [
                types.uint(2),
                types.uint(1),
                types.utf8("Awesome Remix"),
                types.utf8("QmHash456")
            ], creator2.address)
        ]);
        
        assertEquals(remixBlock.receipts[0].result.expectOk(), true);
    }
});

Clarinet.test({
    name: "Can follow creator and update profile",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator1 = accounts.get('deployer')!;
        const creator2 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('wave-trek', 'update-profile', [
                types.utf8("Creator 1"),
                types.utf8("Music Producer")
            ], creator1.address),
            
            Tx.contractCall('wave-trek', 'follow-creator', [
                types.principal(creator1.address)
            ], creator2.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        assertEquals(block.receipts[1].result.expectOk(), true);
        
        let isFollowing = chain.callReadOnlyFn(
            'wave-trek',
            'is-following',
            [
                types.principal(creator2.address),
                types.principal(creator1.address)
            ],
            creator1.address
        );
        
        isFollowing.result.expectOk().expectBool(true);
    }
});