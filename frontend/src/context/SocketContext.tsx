import { createContext, useContext, useEffect, useRef, ReactNode } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuth } from './AuthContext';

interface SocketContextValue {
  socket: Socket | null;
  joinRoom: (room: string) => void;
  leaveRoom: (room: string) => void;
}

const SocketContext = createContext<SocketContextValue>({ socket: null, joinRoom: () => {}, leaveRoom: () => {} });

export function SocketProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth();
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    if (!isAuthenticated) {
      socketRef.current?.disconnect();
      socketRef.current = null;
      return;
    }

    const token = localStorage.getItem('twa_token');
    socketRef.current = io(import.meta.env.VITE_SOCKET_URL ?? 'http://localhost:4000', {
      auth: { token },
      transports: ['websocket'],
    });

    return () => { socketRef.current?.disconnect(); };
  }, [isAuthenticated]);

  const joinRoom = (room: string) => socketRef.current?.emit('join:community', room);
  const leaveRoom = (room: string) => socketRef.current?.emit('leave:community', room);

  return (
    <SocketContext.Provider value={{ socket: socketRef.current, joinRoom, leaveRoom }}>
      {children}
    </SocketContext.Provider>
  );
}

export function useSocket() { return useContext(SocketContext); }
