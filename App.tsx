import React, { useState } from 'react';
import { View, StyleSheet, Text, SafeAreaView } from 'react-native';
import { FingerprintScanner } from './src/components/FingerprintScanner';
import { ApiService } from './src/services/api';
import { theme } from './src/styles/theme';

const apiService = new ApiService();

export default function App() {
  const [studentName, setStudentName] = useState<string | null>(null);
  const [isScanning, setIsScanning] = useState(false);

  const handleScan = async (fingerprintData: string) => {
    setIsScanning(true);
    try {
      const student = await apiService.verifyFingerprint(fingerprintData);
      if (student) {
        setStudentName(student.name);
        await apiService.logAuthentication(student.id, true);
      } else {
        setStudentName(null);
        // Show error message
      }
    } finally {
      setIsScanning(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>
          Student Authentication
        </Text>
        <FingerprintScanner onScanComplete={handleScan} />
        {studentName && (
          <Text style={styles.studentName}>
            Welcome, {studentName}!
          </Text>
        )}
        {isScanning && (
          <Text style={styles.scanningText}>
            Scanning...
          </Text>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: theme.spacing.lg,
  },
  title: {
    fontSize: 24,
    color: theme.colors.text,
    marginBottom: theme.spacing.xl,
    fontWeight: 'bold',
  },
  studentName: {
    fontSize: 20,
    color: theme.colors.primary,
    marginTop: theme.spacing.xl,
  },
  scanningText: {
    fontSize: 16,
    color: theme.colors.textSecondary,
    marginTop: theme.spacing.md,
  }
}); 