import React, { useState } from 'react';
import { View, StyleSheet, Animated } from 'react-native';
import { theme } from '../styles/theme';

interface FingerprintScannerProps {
  onScanComplete: (fingerprintData: string) => void;
}

export const FingerprintScanner: React.FC<FingerprintScannerProps> = ({ onScanComplete }) => {
  const [scanAnimation] = useState(new Animated.Value(0));
  
  const startScanAnimation = () => {
    Animated.sequence([
      Animated.timing(scanAnimation, {
        toValue: 1,
        duration: 1000,
        useNativeDriver: true
      }),
      Animated.timing(scanAnimation, {
        toValue: 0,
        duration: 1000,
        useNativeDriver: true
      })
    ]).start();
  };

  return (
    <View style={styles.container}>
      <Animated.View
        style={[
          styles.scanner,
          {
            opacity: scanAnimation.interpolate({
              inputRange: [0, 1],
              outputRange: [0.5, 1]
            })
          }
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: 200,
    height: 200,
    borderRadius: 100,
    backgroundColor: theme.colors.surface,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 5,
    shadowColor: theme.colors.primary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  scanner: {
    width: 180,
    height: 180,
    borderRadius: 90,
    borderWidth: 2,
    borderColor: theme.colors.primary,
  }
}); 