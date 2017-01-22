// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import LayoutModules
import UIKit

extension LayoutModule
{
    fileprivate static func conditionalTableModule(_ size: CGSize) -> LayoutModule
    {
        return LayoutModule.forMajorAxis(
            horizontal: LayoutModule.table(majorDimension: size.width),
            vertical: LayoutModule.table(majorDimension: size.height)
        )
    }
}

extension LayoutModule
{
    internal static func moduleForSection(_ section: Section,
                                          activityItemSize: CGSize,
                                          errorItemSize: CGSize,
                                          completedItemSize: CGSize,
                                          customHeaderView: UIView?,
                                          valuesLayoutModule: LayoutModule) -> LayoutModule
    {
        switch section
        {
        case .previousPageActivity:
            return conditionalTableModule(activityItemSize)

        case .previousPageError:
            return conditionalTableModule(errorItemSize)

        case .customHeaderView:
            return customHeaderView.map({ view in
                LayoutModule.dynamicTable(calculateMajorDimension: { _, axis, otherDimension in
                    switch axis
                    {
                    case .horizontal:
                        return view.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: otherDimension)).width
                    case .vertical:
                        return view.sizeThatFits(CGSize(width: otherDimension, height: CGFloat.greatestFiniteMagnitude)).height
                    }
                })
            }) ?? LayoutModule.table(majorDimension: 0)

        case .values:
            return valuesLayoutModule

        case .nextPageActivity:
            return conditionalTableModule(activityItemSize)

        case .nextPageError:
            return conditionalTableModule(errorItemSize)

        case .nextPageCompleted:
            return conditionalTableModule(completedItemSize)
        }
    }
}
