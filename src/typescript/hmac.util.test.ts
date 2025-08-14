import { HmacUtil } from './hmac.util'

describe('HmacUtil', () => {
    const testSecretKey = 'its_amazing_secret'
    const testPayload = {
        snapshot: '507f1f77bcf86cd799439011',
        uid: '507f191e810c19729de860ea',
        quest: '507f1f77bcf86cd799439012',
        title: 'Test Quest',
        reward: 1000
    }

    describe('generateSignature', () => {
        it('should generate consistent signatures for same input', () => {
            const timestamp = 1755068549000
            const signature1 = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                '',
                testPayload,
                testSecretKey
            )
            
            const signature2 = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                '',
                testPayload,
                testSecretKey
            )
            
            expect(signature1).toBe(signature2)
            expect(signature1).toBeTruthy()
        })

        it('should generate different signatures for different payloads', () => {
            const timestamp = 1755068549000
            const differentPayload = { ...testPayload, reward: 2000 }
            
            const signature1 = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                '',
                testPayload,
                testSecretKey
            )
            
            const signature2 = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                '',
                differentPayload,
                testSecretKey
            )
            
            expect(signature1).not.toBe(signature2)
        })

        it('should handle query string sorting correctly', () => {
            const timestamp = 1755068549000
            const queryString1 = 'b=2&a=1&c=3'
            const queryString2 = 'a=1&b=2&c=3'
            
            const signature1 = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                queryString1,
                testPayload,
                testSecretKey
            )
            
            const signature2 = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                queryString2,
                testPayload,
                testSecretKey
            )
            
            expect(signature1).toBe(signature2)
        })
    })

    describe('verifySignature', () => {
        it('should verify valid signatures', () => {
            const timestamp = Date.now()
            const signature = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                timestamp,
                '',
                testPayload,
                testSecretKey
            )
            
            const isValid = HmacUtil.verifySignature(
                'POST',
                '/quest/complete',
                '',
                testPayload,
                signature,
                timestamp,
                testSecretKey
            )
            
            expect(isValid).toBe(true)
        })

        it('should reject invalid signatures', () => {
            const timestamp = Date.now()
            const invalidSignature = 'invalid_signature'
            
            const isValid = HmacUtil.verifySignature(
                'POST',
                '/quest/complete',
                '',
                testPayload,
                invalidSignature,
                timestamp,
                testSecretKey
            )
            
            expect(isValid).toBe(false)
        })

        it('should reject expired timestamps', () => {
            const expiredTimestamp = Date.now() - 130000 // 2+ minutes ago
            const signature = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                expiredTimestamp,
                '',
                testPayload,
                testSecretKey
            )
            
            const isValid = HmacUtil.verifySignature(
                'POST',
                '/quest/complete',
                '',
                testPayload,
                signature,
                expiredTimestamp,
                testSecretKey
            )
            
            expect(isValid).toBe(false)
        })

        it('should reject future timestamps', () => {
            const futureTimestamp = Date.now() + 60000 // 1 minute in future
            const signature = HmacUtil.generateSignature(
                'POST',
                '/quest/complete',
                futureTimestamp,
                '',
                testPayload,
                testSecretKey
            )
            
            const isValid = HmacUtil.verifySignature(
                'POST',
                '/quest/complete',
                '',
                testPayload,
                signature,
                futureTimestamp,
                testSecretKey
            )
            
            expect(isValid).toBe(false)
        })
    })
})
