// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import CoreGraphics

// MARK: - Errors

/// A type of cell that can display errors.
public protocol ArrayLoaderErrorDisplaying: class
{
    // MARK: - Error Type

    /// The error type displayed by this cell.
    associatedtype Error: ErrorType

    // MARK: - Error

    /// The error currently displayed by this cell.
    var error: Error? { get set }
}

// MARK: - Values

/// A type of cell that can display a value.
public protocol ArrayLoaderValueDisplaying: class
{
    // MARK: - Value Type

    /// The type of value displayed by this cell.
    associatedtype Value

    // MARK: - Value

    /// The value currently displayed by this cell.
    var value: Value? { get set }
}

// MARK: - Pull-to-Refresh

/// A type of cell that can display a pull-to-refresh interface.
public protocol ArrayLoaderPullToRefreshDisplaying: class
{
    // MARK: - Properties

    /// The number of points necessary to trigger a pull-to-refresh action. This value should be positive.
    static var requiredPullAmount: CGFloat { get }

    /// The current number of points that the user has pulled the scroll view down. This value will be positive.
    var currentPullAmount: CGFloat { get set }
}
