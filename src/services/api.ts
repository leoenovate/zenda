interface StudentProfile {
  id: string;
  name: string;
  studentId: string;
  department: string;
}

export class ApiService {
  private baseUrl: string = 'https://api.university.edu';

  async verifyFingerprint(fingerprintData: string): Promise<StudentProfile | null> {
    try {
      const response = await fetch(`${this.baseUrl}/verify-fingerprint`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ fingerprintData })
      });

      if (!response.ok) {
        throw new Error('Verification failed');
      }

      return await response.json();
    } catch (error) {
      console.error('Error verifying fingerprint:', error);
      return null;
    }
  }

  async logAuthentication(studentId: string, szendaess: boolean): Promise<void> {
    try {
      await fetch(`${this.baseUrl}/log-authentication`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          studentId,
          szendaess,
          timestamp: new Date().toISOString(),
          deviceId: await this.getDeviceId()
        })
      });
    } catch (error) {
      console.error('Error logging authentication:', error);
    }
  }

  private async getDeviceId(): Promise<string> {
    // Implementation depends on the platform
    return 'device-id';
  }
} 