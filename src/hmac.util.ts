import crypto from 'crypto'
import qs from 'qs'

/**
 * HMAC utility for Amazing API authentication
 */
export class HmacUtil {
    
    /**
     * Generate HMAC signature for API request
     */
    static generateSignature(
        method: string,
        uriPath: string,
        timestamp: number,
        queryString: string,
        payload: any,
        secretKey: string
    ): string {
        // Convert payload to JSON string and create SHA256 hash
        const jsonPayload = JSON.stringify(payload)
        const payloadHash = crypto
            .createHash('sha256')
            .update(jsonPayload)
            .digest('hex')
        
        // Sort query string alphabetically
        const sortedQuery = queryString ?
                            qs.stringify(qs.parse(queryString), { sort: (a, b) => a.localeCompare(b) }) : ''
        
        // Create message to sign (separated by newlines)
        const messageToSign = [
            method.toUpperCase(),
            uriPath,
            timestamp.toString(),
            sortedQuery,
            payloadHash
        ].join('\n')
        
        // Generate HMAC SHA-256 signature
        return crypto
            .createHmac('sha256', secretKey)
            .update(messageToSign)
            .digest('base64')
    }
    
    /**
     * Verify HMAC signature with timestamp validation
     */
    static verifySignature(
        method: string,
        uriPath: string,
        queryString: string,
        payload: any,
        signature: string,
        timestamp: number,
        secretKey: string
    ): boolean {
        try {
            // Check if timestamp is expired
            if (this.isExpired(timestamp)) {
                return false
            }
            
            // Generate expected signature using same method
            const expectedSignature = this.generateSignature(
                method,
                uriPath,
                timestamp,
                queryString,
                payload,
                secretKey
            )
            
            // Safe comparison to prevent timing attacks
            const signatureBuffer = Buffer.from(signature, 'base64')
            const expectedBuffer = Buffer.from(expectedSignature, 'base64')
            
            // Return false immediately if lengths differ
            if (signatureBuffer.length !== expectedBuffer.length) {
                return false
            }
            
            return crypto.timingSafeEqual(signatureBuffer, expectedBuffer)
        } catch (error) {
            return false
        }
    }
    
    /**
     * Check if timestamp is expired (requests expire after 2 minutes by default)
     */
    static isExpired(timestamp: number, toleranceMs: number = 120000): boolean {
        const diff = Date.now() - timestamp
        return diff < 0 || diff > toleranceMs
    }
}
